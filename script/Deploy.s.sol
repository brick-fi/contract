// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {PropertyFactory} from "../src/PropertyFactory.sol";

contract PropertyFactoryScript is Script {
    PropertyFactory public factory;

    function setUp() public {}

    function run() public {
        // Get USDC address from environment variable
        address usdcAddress = vm.envAddress("USDC_ADDRESS");
        require(usdcAddress != address(0), "USDC_ADDRESS not set in environment");

        vm.startBroadcast();

        // Deploy PropertyFactory (msg.sender is platform fee recipient)
        factory = new PropertyFactory(usdcAddress, msg.sender);

        console.log("PropertyFactory deployed to:", address(factory));
        console.log("Payment Token (USDC):", usdcAddress);
        console.log("Platform Fee Recipient:", msg.sender);
        console.log("");
        console.log("Property owners can now create properties by calling:");
        console.log("factory.createProperty(name, symbol, propertyInfo)");

        vm.stopBroadcast();
    }
}
