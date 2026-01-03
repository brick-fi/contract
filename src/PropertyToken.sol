// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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

    // ===== Property Metadata =====
    struct PropertyInfo {
        uint256 propertyId;
        string name;
        string location;
        uint256 totalValue;
        uint256 expectedMonthlyIncome;
        uint256 maxSupply; // Total token supply (set by seller)
        string metadataURI; // 3D/2D visual URL
        bool isActive;
    }

    PropertyInfo public property;
    uint256 public pricePerToken; // Calculated from totalValue / maxSupply

    // ===== Compliance Gate =====
    mapping(address => bool) public hasAcceptedTerms;

    event TermsAccepted(address indexed user, uint256 timestamp);

    modifier onlyKYCPassed() {
        require(hasAcceptedTerms[msg.sender], "Must accept terms first");
        _;
    }

    // ===== Distribution =====
    struct Distribution {
        uint256 totalAmount;
        uint256 timestamp;
        uint256 totalSupplyAtDistribution;
        string description;
    }

    Distribution[] public distributions;
    mapping(address => mapping(uint256 => bool)) public hasClaimed;

    event RevenueDistributed(uint256 indexed distributionId, uint256 totalAmount, string description);
    event RevenueClaimed(address indexed user, uint256 indexed distributionId, uint256 amount);
    event Invested(address indexed investor, uint256 amount, uint256 tokens);

    constructor(string memory name, string memory symbol, PropertyInfo memory _property) ERC20(name, symbol) {
        require(_property.maxSupply > 0, "Max supply must be > 0");
        require(_property.totalValue > 0, "Total value must be > 0");

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(DISTRIBUTOR_ROLE, msg.sender);

        property = _property;
        pricePerToken = _property.totalValue / _property.maxSupply;

        // Pre-mint all tokens to contract address
        _mint(address(this), _property.maxSupply);
    }

    // ===== Terms Acceptance =====
    /**
     * @notice Accept terms and conditions for compliance
     * @dev User agreement required before investment
     */
    function acceptTerms() external {
        require(!hasAcceptedTerms[msg.sender], "Already accepted");
        hasAcceptedTerms[msg.sender] = true;
        emit TermsAccepted(msg.sender, block.timestamp);
    }

    // ===== Investment & Token Purchase =====
    /**
     * @notice Invest in property and receive property tokens
     * @dev Tokens are transferred from contract's pre-minted supply
     */
    function invest() external payable onlyKYCPassed whenNotPaused {
        require(msg.value > 0, "Investment amount must be > 0");
        require(property.isActive, "Property not active");

        // Calculate tokens based on property value and max supply
        uint256 tokens = msg.value / pricePerToken;
        require(tokens > 0, "Investment too small");

        uint256 availableTokens = balanceOf(address(this));
        require(availableTokens >= tokens, "Not enough tokens available");

        // Transfer tokens from contract to investor
        _transfer(address(this), msg.sender, tokens);

        emit Invested(msg.sender, msg.value, tokens);
    }

    // ===== Revenue Distribution (Core Feature) =====
    /**
     * @notice Admin triggers revenue distribution
     * @param amount Amount of revenue to distribute (in wei)
     * @param description Description of distribution (e.g., "January 2026 rental income")
     * @dev Creates distribution record that users can claim from
     */
    function distributeRevenue(uint256 amount, string calldata description)
        external
        payable
        onlyRole(DISTRIBUTOR_ROLE)
    {
        require(msg.value == amount, "Amount mismatch");

        // Only count tokens held by investors (exclude unsold tokens in contract)
        uint256 soldTokens = totalSupply() - balanceOf(address(this));
        require(soldTokens > 0, "No tokens sold yet");

        distributions.push(
            Distribution({
                totalAmount: amount,
                timestamp: block.timestamp,
                totalSupplyAtDistribution: soldTokens,
                description: description
            })
        );

        emit RevenueDistributed(distributions.length - 1, amount, description);
    }

    /**
     * @notice Claim revenue from a specific distribution
     * @param distributionId ID of the distribution to claim from
     * @dev Gas-efficient: claim-based instead of automatic push
     */
    function claimRevenue(uint256 distributionId) external onlyKYCPassed {
        require(distributionId < distributions.length, "Invalid distribution");
        require(!hasClaimed[msg.sender][distributionId], "Already claimed");
        require(balanceOf(msg.sender) > 0, "No tokens held");

        Distribution memory dist = distributions[distributionId];

        // Calculate user's share based on token balance
        uint256 userShare = (dist.totalAmount * balanceOf(msg.sender)) / dist.totalSupplyAtDistribution;

        hasClaimed[msg.sender][distributionId] = true;

        payable(msg.sender).transfer(userShare);

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

    // ===== Transfer Restrictions =====
    function _update(address from, address to, uint256 value) internal override whenNotPaused {
        // Skip checks for minting/burning and contract address
        if (from != address(0) && from != address(this)) {
            require(hasAcceptedTerms[from], "Sender must accept terms");
        }
        if (to != address(0) && to != address(this)) {
            require(hasAcceptedTerms[to], "Recipient must accept terms");
        }

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

    function withdraw() external onlyRole(ADMIN_ROLE) {
        payable(msg.sender).transfer(address(this).balance);
    }
}
