// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {DemoUSDC} from "../src/demo/USDC.sol";

contract DeployUSDCScript is Script {
    DemoUSDC public usdc;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy demo USDC
        usdc = new DemoUSDC();
        console.log("Demo USDC deployed to:", address(usdc));
        console.log("Deployer:", msg.sender);

        vm.stopBroadcast();
    }
}
