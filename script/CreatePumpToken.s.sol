// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {PumpFactory} from "../src/PumpFactory.sol";
import {console} from "forge-std/console.sol";

contract CreatePumpToken is Script {
    function run(address factoryAddress, string memory tokenName, string memory tokenSymbol) external {
        vm.startBroadcast();

        PumpFactory factory = PumpFactory(factoryAddress);

        factory.createPumpToken(tokenName, tokenSymbol);

        vm.stopBroadcast();
    }
}