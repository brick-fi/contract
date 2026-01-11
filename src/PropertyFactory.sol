// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./PropertyToken.sol";

/**
 * @title PropertyFactory
 * @notice Factory contract for deploying PropertyToken contracts
 * @dev Allows property owners to create and manage their tokenized properties
 */
contract PropertyFactory {
    // ===== State Variables =====
    address public immutable paymentToken;
    address public platformFeeRecipient;
    PropertyToken[] public allProperties;
    mapping(address => PropertyToken[]) public propertiesByOwner;
    mapping(address => bool) public isPropertyToken;

    // ===== Events =====
    event PropertyCreated(
        address indexed propertyToken,
        address indexed owner,
        string name,
        string symbol,
        uint256 propertyId,
        uint256 totalValue
    );

    // ===== Constructor =====
    constructor(address _paymentToken, address _platformFeeRecipient) {
        require(_paymentToken != address(0), "Payment token cannot be zero address");
        require(_platformFeeRecipient != address(0), "Platform fee recipient cannot be zero address");
        paymentToken = _paymentToken;
        platformFeeRecipient = _platformFeeRecipient;
    }

    // ===== Main Functions =====
    /**
     * @notice Create a new PropertyToken contract
     * @param name Token name (e.g., "BrickFi Property #1")
     * @param symbol Token symbol (e.g., "BRKFI-P1")
     * @param _property Property metadata
     * @return propertyToken Address of the newly deployed PropertyToken
     */
    function createProperty(string memory name, string memory symbol, PropertyToken.PropertyInfo memory _property)
        external
        returns (address propertyToken)
    {
        // Deploy new PropertyToken (msg.sender becomes the owner/admin)
        PropertyToken newProperty =
            new PropertyToken(name, symbol, _property, msg.sender, paymentToken, platformFeeRecipient);

        // Register the property
        allProperties.push(newProperty);
        propertiesByOwner[msg.sender].push(newProperty);
        isPropertyToken[address(newProperty)] = true;

        emit PropertyCreated(address(newProperty), msg.sender, name, symbol, _property.propertyId, _property.totalValue);

        return address(newProperty);
    }

    // ===== View Functions =====
    /**
     * @notice Get total number of properties created
     */
    function getAllPropertiesCount() external view returns (uint256) {
        return allProperties.length;
    }

    /**
     * @notice Get all properties created through this factory
     */
    function getAllProperties() external view returns (PropertyToken[] memory) {
        return allProperties;
    }

    /**
     * @notice Get properties owned by a specific address
     * @param owner Address of the property owner
     */
    function getPropertiesByOwner(address owner) external view returns (PropertyToken[] memory) {
        return propertiesByOwner[owner];
    }

    /**
     * @notice Get number of properties owned by an address
     * @param owner Address of the property owner
     */
    function getPropertiesCountByOwner(address owner) external view returns (uint256) {
        return propertiesByOwner[owner].length;
    }

    /**
     * @notice Check if an address is a PropertyToken deployed by this factory
     * @param token Address to check
     */
    function isValidPropertyToken(address token) external view returns (bool) {
        return isPropertyToken[token];
    }

    /**
     * @notice Get property at specific index
     * @param index Index in the allProperties array
     */
    function getPropertyAt(uint256 index) external view returns (PropertyToken) {
        require(index < allProperties.length, "Index out of bounds");
        return allProperties[index];
    }

    /**
     * @notice Get detailed info for all properties (gas-efficient for frontend)
     * @dev Returns arrays of property details for easy frontend consumption
     */
    struct PropertyDetails {
        address propertyAddress;
        string name;
        string location;
        uint256 totalValue;
        uint256 expectedMonthlyIncome;
        string metadataURI;
        bool isActive;
        uint256 fundingPercentage;
        uint256 investorCount;
        uint256 maxSupply;
        uint256 soldTokens;
    }

    function getAllPropertiesDetails() external view returns (PropertyDetails[] memory) {
        PropertyDetails[] memory details = new PropertyDetails[](allProperties.length);

        for (uint256 i = 0; i < allProperties.length; i++) {
            PropertyToken token = allProperties[i];
            (
                uint256 propertyId,
                string memory name,
                string memory location,
                uint256 totalValue,
                uint256 expectedMonthlyIncome,
                string memory metadataURI,
                bool isActive
            ) = token.property();

            details[i] = PropertyDetails({
                propertyAddress: address(token),
                name: name,
                location: location,
                totalValue: totalValue,
                expectedMonthlyIncome: expectedMonthlyIncome,
                metadataURI: metadataURI,
                isActive: isActive,
                fundingPercentage: token.getFundingPercentage(),
                investorCount: token.getInvestorCount(),
                maxSupply: token.maxSupply(),
                soldTokens: token.getSoldTokens()
            });
        }

        return details;
    }

    /**
     * @notice Get detailed info for a single property
     * @param propertyAddress Address of the property token
     */
    function getPropertyDetails(address propertyAddress) external view returns (PropertyDetails memory) {
        require(isPropertyToken[propertyAddress], "Not a valid property token");

        PropertyToken token = PropertyToken(propertyAddress);
        (
            uint256 propertyId,
            string memory name,
            string memory location,
            uint256 totalValue,
            uint256 expectedMonthlyIncome,
            string memory metadataURI,
            bool isActive
        ) = token.property();

        return PropertyDetails({
            propertyAddress: propertyAddress,
            name: name,
            location: location,
            totalValue: totalValue,
            expectedMonthlyIncome: expectedMonthlyIncome,
            metadataURI: metadataURI,
            isActive: isActive,
            fundingPercentage: token.getFundingPercentage(),
            investorCount: token.getInvestorCount(),
            maxSupply: token.maxSupply(),
            soldTokens: token.getSoldTokens()
        });
    }
}
