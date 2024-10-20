// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PumpToken.sol";

contract PumpFactory is Ownable {
    // State variable to keep track of all deployed PumpTokens
    PumpToken[] public deployedTokens;

    address public uniswapV2Router;

    event PumpTokenCreated(address tokenAddress, address indexed owner);

    constructor(address uniswapV2Router_) Ownable(msg.sender){
        uniswapV2Router = uniswapV2Router_;
    }
    // Function to create a new PumpToken
    function createPumpToken(
        string memory name,
        string memory symbol,
        uint32 reserveRatio
    ) external onlyOwner {
        // Deploy a new PumpToken instance
        PumpToken newToken = new PumpToken();

        // Initialize the PumpToken (calling its initialize function)
        newToken.initialize(name, symbol, address(this), uniswapV2Router, reserveRatio);

        // Add the newly created PumpToken to the array
        deployedTokens.push(newToken);

        // Emit an event for the new PumpToken creation
        emit PumpTokenCreated(address(newToken), msg.sender);
    }

    // Function for the owner to collect the accumulated ETH fees in the contract
    function collectFee() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to collect");
        
        // Transfer the balance to the owner
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Failed to transfer the fee to the owner");
    }

    // Fallback function to accept ETH payments
    receive() external payable {}
}
