// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "forge-std/Test.sol";
// import "forge-std/console.sol";
// import "../src/PumpFactory.sol";
// import "../src/PumpToken.sol";

// contract BondingCurveTest is Test {
//     address public constant uniswapV2Router =
//         0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

//     address public constant owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

//     PumpFactory public pumpFactory;
//     PumpToken public pumpToken;
//     PumpToken public deployedToken;

//     address public constant user1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

//     function setUp() public {
//         vm.deal(user1, 10 ether);
//         vm.startBroadcast(owner);
//         pumpToken = new PumpToken();
//         pumpFactory = new PumpFactory(uniswapV2Router, address(pumpToken));
//         vm.stopBroadcast();
//         deployPumpToken();
//     }

//     function deployPumpToken() public {
//         vm.startBroadcast(user1);
//         string memory name = "Pump Token";
//         string memory symbol = "PUMP";
//         uint32 reserveRatio = 1e5; // 1 / 10 => y = m * x ^ 9

//         pumpFactory.createPumpToken{value: 0.01 ether}(name, symbol, reserveRatio);
//         vm.stopBroadcast();

//         // Check the deployed token
//         deployedToken = PumpToken(address(pumpFactory.deployedTokens(0)));
//         assertEq(
//             deployedToken.symbol(),
//             symbol,
//             "Token should have the right symbol"
//         );
//         assertEq(
//             address(deployedToken.uniswapV2Router()),
//             uniswapV2Router,
//             "Univ2 router should have been set"
//         );
//         assertEq(deployedToken.totalRaised(), 0, "Total raised should be 0");
//         assertEq(deployedToken.totalSupply(), 1e18, "Should have initital supply");
//         assertEq(deployedToken.poolBalance(), 0.01 ether, "Should have initital reserve");
//         assertEq(
//             pumpFactory.isDeployedToken(address(deployedToken)),
//             true,
//             "Token should be recognized by the factory"
//         );
//     }

//     function testBuy() public {
//         uint256 tokenBefore = deployedToken.balanceOf(user1);
//         assertEq(tokenBefore, 0, "Initial balance should be 0");
//         vm.startBroadcast(user1);
//         uint256 minAmountOut = 0; // Ensure this value works as expected
//         deployedToken.buy{value: 0.01 ether}(minAmountOut, user1);
//         vm.stopBroadcast();
//     }
// }
