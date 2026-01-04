// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {PropertyFactory} from "../src/PropertyFactory.sol";

contract PropertyFactoryScript is Script {
    PropertyFactory public factory;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy PropertyFactory
        factory = new PropertyFactory();

        console.log("PropertyFactory deployed to:", address(factory));
        console.log("Deployer:", msg.sender);
        console.log("");
        console.log("Property owners can now create properties by calling:");
        console.log("factory.createProperty(name, symbol, propertyInfo)");

        vm.stopBroadcast();
    }
}
