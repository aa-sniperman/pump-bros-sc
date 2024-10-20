// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract PumpTokenTest is Test {
    address public constant uniswapV2Router =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address public constant deployerAddress =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant user1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public constant user2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public constant user3 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address public constant user4 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
    address public constant user5 = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;

  function setUp() public {
    vm.startBroadcast(deployerAddress);
    
    vm.stopBroadcast();
  }
}
