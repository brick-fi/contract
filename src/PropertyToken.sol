// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title BrickFi Property Token
 * @notice Represents rental income rights from real estate properties
 * @dev ERC-20 based token with distribution mechanisms for rental revenue
 */
contract PropertyToken is ERC20, AccessControl, Pausable, ERC20Burnable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    uint256 public constant TOKEN_PRICE = 50 * 1e6; // Each token = $50 USD (6 decimals for standard stablecoins)
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 2; // 2% platform fee
    uint256 public constant MIN_INVESTMENT = 50 * 1e6; // Minimum $50 investment

    // ===== Payment Token =====
    IERC20 public immutable paymentToken;
    address public platformFeeRecipient;

    // ===== Property Metadata =====
    struct PropertyInfo {
        string name;
        string location;
        uint256 totalValue;
        uint256 expectedMonthlyIncome;
        string metadataURI;
        bool isActive;
    }

    PropertyInfo public property;
    uint256 public maxSupply; // Auto-calculated: totalValue / TOKEN_PRICE

    // ===== Investor Tracking =====
    address[] private investors;
    mapping(address => bool) private isInvestor;
    mapping(address => uint256) public investmentAmount; // Total USDC invested by each investor

    event PlatformFeeCollected(uint256 amount, address recipient);

    // ===== Distribution =====
    enum DistributionStatus {
        Pending,
        Distributed
    }

    struct Distribution {
        uint256 totalAmount;
        uint256 timestamp;
        uint256 totalSupplyAtDistribution;
        string description;
        DistributionStatus status;
    }

    Distribution[] public distributions;
    mapping(address => mapping(uint256 => bool)) public hasClaimed;

    event RevenueDistributed(uint256 indexed distributionId, uint256 totalAmount, string description);
    event RevenueClaimed(address indexed user, uint256 indexed distributionId, uint256 amount);
    event Invested(address indexed investor, uint256 amount, uint256 tokens);

    constructor(
        string memory name,
        string memory symbol,
        PropertyInfo memory _property,
        address owner,
        address _paymentToken,
        address _platformFeeRecipient
    ) ERC20(name, symbol) {
        require(_property.totalValue > 0, "Total value must be > 0");
        require(_property.totalValue >= TOKEN_PRICE, "Total value must be >= TOKEN_PRICE");
        require(owner != address(0), "Owner cannot be zero address");
        require(_paymentToken != address(0), "Payment token cannot be zero address");
        require(_platformFeeRecipient != address(0), "Platform fee recipient cannot be zero address");

        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(ADMIN_ROLE, owner);
        _grantRole(DISTRIBUTOR_ROLE, owner);

        paymentToken = IERC20(_paymentToken);
        platformFeeRecipient = _platformFeeRecipient;
        property = _property;

        // Calculate max supply: totalValue / $50
        // Payment token has 6 decimals, property token has 18 decimals
        maxSupply = (_property.totalValue * 1e18) / TOKEN_PRICE;
        require(maxSupply > 0, "Max supply must be > 0");

        // Pre-mint all tokens to contract address
        _mint(address(this), maxSupply);
    }

    // ===== Investment & Token Purchase =====
    /**
     * @notice Invest in property and receive property tokens
     * @dev Tokens are transferred from contract's pre-minted supply
     * @dev Each token represents $50 USD of property value
     * @dev 2% platform fee is deducted from investment amount
     * @param amount Amount of payment token to invest (with payment token decimals)
     */
    function invest(uint256 amount) external whenNotPaused {
        require(amount >= MIN_INVESTMENT, "Investment must be at least $50");
        require(property.isActive, "Property not active");

        // Calculate platform fee (2%)
        uint256 platformFee = (amount * PLATFORM_FEE_PERCENTAGE) / 100;
        uint256 investmentAfterFee = amount - platformFee;

        // Calculate tokens: Each token = $50 USD
        // amount is in payment token units (6 decimals), TOKEN_PRICE is in payment token units (6 decimals)
        // Property tokens have 18 decimals
        uint256 tokens = (investmentAfterFee * 1e18) / TOKEN_PRICE;
        require(tokens > 0, "Investment too small");

        uint256 availableTokens = balanceOf(address(this));
        require(availableTokens >= tokens, "Not enough tokens available");

        // Transfer payment token from investor to contract
        require(
            paymentToken.transferFrom(msg.sender, address(this), investmentAfterFee), "Payment token transfer failed"
        );

        // Transfer platform fee
        require(
            paymentToken.transferFrom(msg.sender, platformFeeRecipient, platformFee), "Platform fee transfer failed"
        );

        // Track investor
        if (!isInvestor[msg.sender]) {
            investors.push(msg.sender);
            isInvestor[msg.sender] = true;
        }
        investmentAmount[msg.sender] += amount;

        // Transfer property tokens from contract to investor
        _transfer(address(this), msg.sender, tokens);

        emit Invested(msg.sender, amount, tokens);
        emit PlatformFeeCollected(platformFee, platformFeeRecipient);
    }

    // ===== Revenue Distribution (Core Feature) =====
    /**
     * @notice Admin triggers revenue distribution
     * @param amount Amount of revenue to distribute (in payment token units)
     * @param description Description of distribution (e.g., "January 2026 rental income")
     * @dev Creates distribution record that users can claim from
     */
    function distributeRevenue(uint256 amount, string calldata description) external onlyRole(DISTRIBUTOR_ROLE) {
        require(amount > 0, "Amount must be > 0");

        // Only count tokens held by investors (exclude unsold tokens in contract)
        uint256 soldTokens = totalSupply() - balanceOf(address(this));
        require(soldTokens > 0, "No tokens sold yet");

        // Transfer payment token from distributor to contract
        require(paymentToken.transferFrom(msg.sender, address(this), amount), "Payment token transfer failed");

        distributions.push(
            Distribution({
                totalAmount: amount,
                timestamp: block.timestamp,
                totalSupplyAtDistribution: soldTokens,
                description: description,
                status: DistributionStatus.Distributed
            })
        );

        emit RevenueDistributed(distributions.length - 1, amount, description);
    }

    /**
     * @notice Claim revenue from a specific distribution
     * @param distributionId ID of the distribution to claim from
     * @dev Gas-efficient: claim-based instead of automatic push
     */
    function claimRevenue(uint256 distributionId) external {
        require(distributionId < distributions.length, "Invalid distribution");
        require(!hasClaimed[msg.sender][distributionId], "Already claimed");
        require(balanceOf(msg.sender) > 0, "No tokens held");

        Distribution memory dist = distributions[distributionId];

        // Calculate user's share based on token balance
        uint256 userShare = (dist.totalAmount * balanceOf(msg.sender)) / dist.totalSupplyAtDistribution;
        require(userShare > 0, "No revenue to claim");

        hasClaimed[msg.sender][distributionId] = true;

        // Transfer payment token to user
        require(paymentToken.transfer(msg.sender, userShare), "Payment token transfer failed");

        emit RevenueClaimed(msg.sender, distributionId, userShare);
    }

    // ===== View Functions =====
    function getDistributionCount() external view returns (uint256) {
        return distributions.length;
    }

    function getPendingRevenue(address user, uint256 distributionId) external view returns (uint256) {
        if (distributionId >= distributions.length) return 0;
        if (hasClaimed[user][distributionId]) return 0;
        if (balanceOf(user) == 0) return 0;

        Distribution memory dist = distributions[distributionId];
        return (dist.totalAmount * balanceOf(user)) / dist.totalSupplyAtDistribution;
    }

    function getDistribution(uint256 distributionId) external view returns (Distribution memory) {
        require(distributionId < distributions.length, "Invalid distribution");
        return distributions[distributionId];
    }

    function getAvailableTokens() external view returns (uint256) {
        return balanceOf(address(this));
    }

    function getSoldTokens() external view returns (uint256) {
        return totalSupply() - balanceOf(address(this));
    }

    /**
     * @notice Get number of unique investors
     */
    function getInvestorCount() external view returns (uint256) {
        return investors.length;
    }

    /**
     * @notice Get list of all investors
     */
    function getInvestors() external view returns (address[] memory) {
        return investors;
    }

    /**
     * @notice Get funding percentage (0-100)
     */
    function getFundingPercentage() external view returns (uint256) {
        uint256 sold = totalSupply() - balanceOf(address(this));
        if (totalSupply() == 0) return 0;
        return (sold * 100) / totalSupply();
    }

    /**
     * @notice Calculate user's projected monthly income based on current holdings
     * @param user Address of the user
     * @return Projected monthly income in payment token units
     * @dev Uses maxSupply (total issued tokens) not soldTokens for calculation
     * @dev Each token has a fixed monthly income regardless of how many are sold
     */
    function getUserProjectedMonthlyIncome(address user) external view returns (uint256) {
        uint256 userTokens = balanceOf(user);
        if (userTokens == 0) return 0;
        if (maxSupply == 0) return 0;

        // User's share based on total supply (not sold tokens)
        // Each token represents a fixed portion of the total monthly income
        return (property.expectedMonthlyIncome * userTokens) / maxSupply;
    }

    /**
     * @notice Get total amount invested by a specific user
     * @param user Address of the user
     * @return Total USDC invested
     */
    function getUserInvestmentAmount(address user) external view returns (uint256) {
        return investmentAmount[user];
    }

    // ===== Transfer Restrictions =====
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        super._update(from, to, value);
    }

    // ===== Admin Functions =====
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function updatePropertyMetadata(string calldata metadataURI) external onlyRole(ADMIN_ROLE) {
        property.metadataURI = metadataURI;
    }

    function setPropertyActive(bool active) external onlyRole(ADMIN_ROLE) {
        property.isActive = active;
    }

    function withdrawPaymentToken() external onlyRole(ADMIN_ROLE) {
        uint256 balance = paymentToken.balanceOf(address(this));
        require(balance > 0, "No payment token to withdraw");
        require(paymentToken.transfer(msg.sender, balance), "Payment token transfer failed");
    }
}
