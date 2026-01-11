// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {PropertyFactory} from "../src/PropertyFactory.sol";
import {DemoUSDC} from "../src/demo/USDC.sol";

contract PropertyFactoryScript is Script {
    PropertyFactory public factory;
    DemoUSDC public paymentToken;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy demo USDC first
        paymentToken = new DemoUSDC();
        console.log("Demo USDC deployed to:", address(paymentToken));

        // Deploy PropertyFactory (msg.sender is platform fee recipient)
        factory = new PropertyFactory(address(paymentToken), msg.sender);

        console.log("PropertyFactory deployed to:", address(factory));
        console.log("Payment Token:", address(paymentToken));
        console.log("Deployer:", msg.sender);
        console.log("");
        console.log("Property owners can now create properties by calling:");
        console.log("factory.createProperty(name, symbol, propertyInfo)");

        vm.stopBroadcast();
    }
}
