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
    uint256 public minInvestment; // Minimum investment amount (default: $50)

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
        minInvestment = 50 * 1e6; // Default: $50 minimum

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
     * @dev 2% platform fee is deducted from the total amount sent
     * @param totalAmount Total amount of payment token (investment + 2% fee)
     * @dev Example: To invest $100, send $102 (100 + 2% fee of 2)
     */
    function invest(uint256 totalAmount) external whenNotPaused {
        require(totalAmount >= minInvestment, "Investment below minimum");
        require(property.isActive, "Property not active");

        // Calculate platform fee (2% of total)
        // fee = totalAmount * 2 / 100 = totalAmount * 2 / 100
        uint256 platformFee = (totalAmount * PLATFORM_FEE_PERCENTAGE) / (100 + PLATFORM_FEE_PERCENTAGE);
        uint256 amountAfterFee = totalAmount - platformFee;

        // Calculate tokens: Each token = $50 USD
        // amountAfterFee is in payment token units (6 decimals), TOKEN_PRICE is in payment token units (6 decimals)
        // Property tokens have 18 decimals
        uint256 tokens = (amountAfterFee * 1e18) / TOKEN_PRICE;
        require(tokens > 0, "Investment too small");

        uint256 availableTokens = balanceOf(address(this));
        require(availableTokens >= tokens, "Not enough tokens available");

        // Transfer payment token from investor to contract
        require(paymentToken.transferFrom(msg.sender, address(this), amountAfterFee), "Payment token transfer failed");

        // Transfer platform fee
        require(
            paymentToken.transferFrom(msg.sender, platformFeeRecipient, platformFee), "Platform fee transfer failed"
        );

        // Track investor
        if (!isInvestor[msg.sender]) {
            investors.push(msg.sender);
            isInvestor[msg.sender] = true;
        }
        investmentAmount[msg.sender] += amountAfterFee;

        // Transfer property tokens from contract to investor
        _transfer(address(this), msg.sender, tokens);

        emit Invested(msg.sender, amountAfterFee, tokens);
        emit PlatformFeeCollected(platformFee, platformFeeRecipient);
    }

    // ===== Revenue Distribution (Core Feature) =====
    /**
     * @notice Admin triggers revenue distribution proportional to sold tokens
     * @param expectedAmount Expected revenue amount IF ALL tokens were sold (in payment token units)
     * @param description Description of distribution (e.g., "January 2026 rental income")
     * @dev Admin inputs expectedAmount as if all tokens were sold, but contract calculates actualAmount
     * @dev actualAmount = expectedAmount * (soldTokens / maxSupply)
     * @dev Example: expectedAmount = 10,000 USDC, sold = 2 tokens, maxSupply = 2000
     *      → actualAmount = 10,000 * (2 / 2000) = 10 USDC
     *      → Admin only transfers 10 USDC (not 10,000)
     *      → Each token owner gets: 10 / 2 = 5 USDC each when they claim
     * @dev This prevents wasting money on unsold token shares
     */
    function distributeRevenue(uint256 expectedAmount, string calldata description)
        external
        onlyRole(DISTRIBUTOR_ROLE)
    {
        require(expectedAmount > 0, "Amount must be > 0");

        // Check that at least some tokens are sold
        uint256 soldTokens = totalSupply() - balanceOf(address(this));
        require(soldTokens > 0, "No tokens sold yet");

        // Calculate actual amount to transfer based on sold token percentage
        // actualAmount = expectedAmount * (soldTokens / maxSupply)
        uint256 actualAmount = (expectedAmount * soldTokens) / maxSupply;
        require(actualAmount > 0, "Distribution amount too small");

        // Transfer the actual amount from distributor to contract
        require(paymentToken.transferFrom(msg.sender, address(this), actualAmount), "Payment token transfer failed");

        // Automatically distribute to all investors (push-based)
        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 investorTokens = balanceOf(investor);

            if (investorTokens > 0) {
                uint256 investorShare = (actualAmount * investorTokens) / soldTokens;
                if (investorShare > 0) {
                    require(paymentToken.transfer(investor, investorShare), "Failed to distribute to investor");
                }
            }
        }

        // Store distribution record for reference
        distributions.push(
            Distribution({
                totalAmount: actualAmount,
                timestamp: block.timestamp,
                totalSupplyAtDistribution: soldTokens,
                description: description,
                status: DistributionStatus.Distributed
            })
        );

        emit RevenueDistributed(distributions.length - 1, actualAmount, description);
    }

    /**
     * @notice Claim revenue from a specific distribution
     * @param distributionId ID of the distribution to claim from
     * @dev Gas-efficient: claim-based (pull) instead of automatic push
     * @dev User must actively call this to receive their share
     * @dev Each token owner gets equal share: (actualAmount * userTokens) / soldTokens
     * @dev Example: actualAmount = 10 USDC, user has 1 token, 2 tokens sold
     *      → user gets (10 * 1) / 2 = 5 USDC
     */
    function claimRevenue(uint256 distributionId) external {
        require(distributionId < distributions.length, "Invalid distribution");
        require(!hasClaimed[msg.sender][distributionId], "Already claimed");
        require(balanceOf(msg.sender) > 0, "No tokens held");

        Distribution memory dist = distributions[distributionId];

        // Calculate user's share based on token balance and sold tokens
        // dist.totalSupplyAtDistribution is now soldTokens (not maxSupply)
        // Each token owner gets equal share: (actualAmount * userTokens) / soldTokens
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

    /**
     * @notice Get amount pending for user to claim from a distribution
     * @param user Address of user
     * @param distributionId ID of distribution
     * @return Amount user can claim (0 if already claimed or no tokens held)
     */
    function getPendingRevenue(address user, uint256 distributionId) external view returns (uint256) {
        if (distributionId >= distributions.length) return 0;
        if (hasClaimed[user][distributionId]) return 0;
        if (balanceOf(user) == 0) return 0;

        Distribution memory dist = distributions[distributionId];
        // Calculate: (actualAmount * userTokens) / soldTokens
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

    /**
     * @notice Get minimum investment amount required
     * @return Minimum investment amount in payment token units (6 decimals)
     */
    function getMinInvestment() external view returns (uint256) {
        return minInvestment;
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

    function setMinInvestment(uint256 _minInvestment) external onlyRole(ADMIN_ROLE) {
        require(_minInvestment > 0, "Minimum investment must be > 0");
        minInvestment = _minInvestment;
    }

    function withdrawPaymentToken() external onlyRole(ADMIN_ROLE) {
        uint256 balance = paymentToken.balanceOf(address(this));
        require(balance > 0, "No payment token to withdraw");
        require(paymentToken.transfer(msg.sender, balance), "Payment token transfer failed");
    }
}
