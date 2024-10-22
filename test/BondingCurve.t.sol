// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/PumpFactory.sol";
import "../src/PumpToken.sol";
import "../src/interfaces/IUniswapV2Factory.sol";
import "../src/interfaces/IUniswapV2Pair.sol";

contract BondingCurveTest is Test {
    address public constant uniswapV2Router =
        0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008;

    address public constant owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 private constant TOKEN_CREATION_FEE = 0.5 ether; // 0.5 ETH
    uint256 private constant LISTING_FEE = 1 ether; // 1 ETH
    uint256 private constant LISTING_THRESHOLD = 366.67 ether;
    PumpFactory public pumpFactory;
    PumpToken public pumpToken;
    PumpToken public deployedToken;

    address public constant user1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public constant user2 = 0xA00a593B4160Fc26aF93Cf5bd88ab475228aaaC5;
    address public constant user3 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() public {
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
        vm.deal(user3, 1000 ether);
        vm.startBroadcast(owner);
        pumpToken = new PumpToken();
        pumpFactory = new PumpFactory(uniswapV2Router, address(pumpToken));
        vm.stopBroadcast();
        deployPumpToken();
    }

    function deployPumpToken() public {
        vm.startBroadcast(user1);
        string memory name = "Pump Token";
        string memory symbol = "PUMP";

        uint256 inititalDeposit = 0.01 ether;

        pumpFactory.createPumpToken{
            value: TOKEN_CREATION_FEE + LISTING_FEE + inititalDeposit
        }(name, symbol);
        vm.stopBroadcast();

        // Check the deployed token
        deployedToken = PumpToken(address(pumpFactory.deployedTokens(0)));
        assertEq(
            deployedToken.symbol(),
            symbol,
            "Token should have the right symbol"
        );
        assertEq(
            address(deployedToken.uniswapV2Router()),
            uniswapV2Router,
            "Univ2 router should have been set"
        );
        assertGt(deployedToken.totalRaised(), 0, "Should have total raise");
        assertGt(
            deployedToken.poolBalance(),
            0,
            "Should have initital reserve"
        );
        assertGt(deployedToken.totalSupply(), 0, "Should have supply");
        assertEq(
            pumpFactory.isDeployedToken(address(deployedToken)),
            true,
            "Token should be recognized by the factory"
        );
    }

    function buy(address sender, uint256 amount) internal {
        vm.startBroadcast(sender);
        deployedToken.buy{value: amount}(0, sender);
        vm.stopBroadcast();
    }

    function sell(address sender, uint256 amount) internal {
        vm.startBroadcast(sender);
        deployedToken.sell(amount, 0, sender);
        vm.stopBroadcast();
    }

    function pump(address sender, uint256 amount) internal {
        vm.startBroadcast(sender);
        deployedToken.pump(amount);
        vm.stopBroadcast();
    }

    function testBuy() public {
        uint256 reserveBefore = deployedToken.totalReserve();
        uint256 tokenBefore = deployedToken.balanceOf(user2);
        assertEq(tokenBefore, 0, "Initial balance should be 0");
        buy(user2, 0.01 ether);
        uint256 tokenAfter = deployedToken.balanceOf(user2);
        assertGt(tokenAfter, 0, "Should earn token");
        uint256 reserveAfter = deployedToken.totalReserve();
        assertEq(
            reserveBefore + 0.0005 ether,
            reserveAfter,
            "Wrong reserve calculation"
        );
    }

    function testSell() public {
        uint256 token0 = deployedToken.balanceOf(user3);
        uint256 reserve0 = deployedToken.totalReserve();
        uint256 poolBal0 = deployedToken.poolBalance();
        uint256 raised0 = deployedToken.totalRaised();

        buy(user3, 1 ether);
        uint256 token1 = deployedToken.balanceOf(user3);
        uint256 reserve1 = deployedToken.totalReserve();
        uint256 poolBal1 = deployedToken.poolBalance();
        uint256 raised1 = deployedToken.totalRaised();
        sell(user3, token1);

        uint256 token2 = deployedToken.balanceOf(user3);
        uint256 reserve2 = deployedToken.totalReserve();
        uint256 poolBal2 = deployedToken.poolBalance();
        uint256 raised2 = deployedToken.totalRaised();

        assertEq(token0, 0, "Initial balance should be 0");
        assertEq(reserve1, reserve0 + 0.05 ether, "Wrong reserve change at 1");
        assertEq(poolBal1, poolBal0 + 0.94 ether, "Wrong pool bal change at 1");
        assertEq(
            raised1,
            raised0 + 0.94 ether,
            "Wrong total raised change at 1"
        );
        assertEq(token2, 0, "Should sell all tokens");
        assertLt(
            reserve2 + 1 ether - reserve1 - 0.047 ether,
            1 ether + 10,
            "Wrong reserve change at 2"
        );
        assertLt(poolBal2 - poolBal0, 10, "Wrong pool bal change at 2");
        assertLt(
            raised1 + 1 ether - raised2 - 0.94 ether,
            1 ether + 10,
            "Wrong total raised change at 2"
        );
    }

    function testPump() public {
        uint256 userPump0 = deployedToken.pumped(user3);
        uint256 pump0 = deployedToken.totalPumped();

        buy(user3, 10 ether);

        uint256 token1 = deployedToken.balanceOf(user3);

        buy(user3, 5 ether);

        uint256 token2 = deployedToken.balanceOf(user3) - token1;

        pump(user3, token1);

        uint256 userPump1 = deployedToken.pumped(user3);
        uint256 pump1 = deployedToken.totalPumped();

        sell(user3, token2);

        uint256 userPump2 = deployedToken.pumped(user3);
        uint256 pump2 = deployedToken.totalPumped();

        assertEq(userPump0, 0, "Wrong user pump at 0");
        assertEq(pump0, 0, "Wrong pump at 0");
        assertEq(userPump1, token1, "Wrong user pump at 1");
        assertEq(pump1, token1, "Wrong pump at 1");
        assertEq(userPump2, token1 - token2, "Wrong user pump at 2");
        assertEq(pump2, token1 - token2, "Wrong pump at 2");
    }

    function testPumpAndAutoBuy() public {
        uint256 pump0 = deployedToken.totalPumped();
        uint256 reserve0 = deployedToken.totalReserve();

        buy(user1, 10 ether);

        uint256 user1Token = deployedToken.balanceOf(user1);

        pump(user1, user1Token);

        uint256 pump1 = deployedToken.totalPumped();
        uint256 reserve1 = deployedToken.totalReserve();

        buy(user2, 40 ether);

        uint256 user2Token = deployedToken.balanceOf(user2);

        pump(user2, user2Token);

        uint256 pump2 = deployedToken.totalPumped();
        uint256 reserve2 = deployedToken.totalReserve();

        buy(user3, 10 ether);

        uint256 user3Token = deployedToken.balanceOf(user3);

        pump(user3, user3Token);

        uint256 pump3 = deployedToken.totalPumped();
        uint256 reserve3 = deployedToken.totalReserve();

        assertEq(reserve1, reserve0 + 0.5 ether, "Wrong reserve change at 1");
        assertEq(pump1, pump0 + user1Token, "Wrong pump change at 1");
        assertEq(reserve2, reserve1 + 2 ether, "Wrong reserve change at 2");
        assertEq(pump2, pump1 + user2Token, "Wrong pump change at 2");
        assertEq(reserve3, 0, "Wrong reserve change at 3");
        assertEq(pump3, pump2 + user3Token, "Wrong pump change at 3");
    }

    function testBuyAndList() public {
        buy(user1, 10 ether);
        buy(user2, 40 ether);
        buy(user3, LISTING_THRESHOLD - 35 ether);

        uint256 user3Token = deployedToken.balanceOf(user3);

        pump(user3, user3Token);
    }
}
