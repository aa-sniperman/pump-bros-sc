// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

// Only for testing
import {console} from "forge-std/console.sol";

contract PumpFactory is Ownable {

    // State variable to keep track of all deployed PumpTokens
    ERC1967Proxy[] public deployedTokens;

    address public uniswapV2Router;
    address public pumpImplementation;

    event PumpTokenCreated(address tokenAddress, address indexed owner);
    event PumpImplementationUpdated(address newImplementation);

    constructor(address uniswapV2Router_, address pumpImplementation_) Ownable(msg.sender){
        uniswapV2Router = uniswapV2Router_;
        pumpImplementation = pumpImplementation_;
    }

    // Function to create a new PumpToken
    function createPumpToken(
        string memory name,
        string memory symbol
    ) external payable {
        // Deploy a new PumpToken instance
        ERC1967Proxy newToken = new ERC1967Proxy{value: msg.value}(
            pumpImplementation,
            abi.encodeWithSelector(0xdb0ed6a0, name, symbol, owner(), msg.sender, uniswapV2Router)
        );

        // Add the newly created PumpToken to the array
        deployedTokens.push(newToken);

        // Emit an event for the new PumpToken creation
        emit PumpTokenCreated(address(newToken), msg.sender);

        console.log("token created: %s", address(newToken));
    }

    // Function to update the pumpImplementation address
    function updatePumpImplementation(address newImplementation) external onlyOwner {
        require(newImplementation != address(0), "Invalid address");
        pumpImplementation = newImplementation;

        emit PumpImplementationUpdated(newImplementation);
    }

    // Helper function to check if a token is deployed by this factory
    function isDeployedToken(address tokenProxy) public view returns (bool) {
        for (uint256 i = 0; i < deployedTokens.length; i++) {
            if (address(deployedTokens[i]) == tokenProxy) {
                return true;
            }
        }
        return false;
    }
}
