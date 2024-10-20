// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {PumpFactory} from "../src/PumpFactory.sol";
import {console} from "forge-std/console.sol";

contract CreatePumpToken is Script {
    function run() external {
        vm.startBroadcast();

        PumpFactory factory = PumpFactory();

        address newTokenAddress = factory.createPumpToken(tokenName, tokenSymbol, 100);
        console.log("New token deployed at address:", newTokenAddress);

        vm.stopBroadcast();
    }
}