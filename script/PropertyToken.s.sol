// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {PropertyToken} from "../src/PropertyToken.sol";

contract PropertyTokenScript is Script {
    PropertyToken public token;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Property metadata
        PropertyToken.PropertyInfo memory property = PropertyToken.PropertyInfo({
            propertyId: 1,
            name: "Sunset Boulevard Apartments",
            location: "Los Angeles, CA",
            totalValue: 500000 * 1e18, // $500,000 property value
            expectedMonthlyIncome: 3200 * 1e18, // $3,200/month expected
            metadataURI: "ipfs://QmExample123456789", // Replace with actual IPFS URI
            isActive: true
        });

        // Deploy PropertyToken
        token = new PropertyToken("BrickFi Property #1", "BRKFI-P1", property);

        console.log("PropertyToken deployed to:", address(token));
        console.log("Property ID:", property.propertyId);
        console.log("Property Name:", property.name);
        console.log("Property Location:", property.location);
        console.log("Total Value:", property.totalValue);
        console.log("Max Supply (auto-calculated):", token.maxSupply());
        console.log("Token Price (fixed):", token.TOKEN_PRICE());

        vm.stopBroadcast();
    }
}
