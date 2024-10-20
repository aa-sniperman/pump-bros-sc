// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/PumpFactory.sol";
import "../src/PumpToken.sol";

contract PumpTokenTest is Test {
    address public constant uniswapV2Router = 
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address public constant owner = 
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    PumpFactory public pumpFactory;
    PumpToken public pumpToken;

    address public constant user1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public constant newPumpImplementation = 0x1234567890123456789012345678901234567890; // mock new implementation address

    function setUp() public {
        vm.startBroadcast(owner);
        pumpToken = new PumpToken();
        pumpFactory = new PumpFactory(uniswapV2Router, address(pumpToken));
        vm.stopBroadcast();
    }

    function testFactoryInitialSetup() public view {
        assertEq(pumpFactory.uniswapV2Router(), uniswapV2Router, "UniswapV2Router should be set correctly");
        assertEq(pumpFactory.pumpImplementation(), address(pumpToken), "PumpToken implementation should be set correctly");
    }

    function testDeployPumpToken() public {
        vm.startBroadcast(user1);
        string memory name = "Pump Token";
        string memory symbol = "PUMP";
        uint32 reserveRatio = 100;
        

        pumpFactory.createPumpToken(name, symbol, reserveRatio);
        vm.stopBroadcast();

        // Check the deployed token
        ERC1967Proxy deployedToken = pumpFactory.deployedTokens(0);
        assertEq(pumpFactory.isDeployedToken(address(deployedToken)), true, "Token should be recognized by the factory");
    }

    function testUpdatePumpImplementation() public {
        vm.startBroadcast(owner);

        pumpFactory.updatePumpImplementation(newPumpImplementation);
        assertEq(pumpFactory.pumpImplementation(), newPumpImplementation, "Implementation should be updated");

        vm.stopBroadcast();
    }

    function testOnlyOwnerCanUpdateImplementation() public {
        vm.startBroadcast(user1);

        vm.expectRevert();
        pumpFactory.updatePumpImplementation(newPumpImplementation);

        vm.stopBroadcast();
    }
}
