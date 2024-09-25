// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./BancorFormula.sol";

abstract contract BondingCurve is ERC20Upgradeable, BancorFormula {
    /**
     * @dev Available balance of reserve token in contract
     */
    uint256 public poolBalance;

    /*
     * @dev reserve ratio, represented in ppm, 1-1000000
     * 1/3 corresponds to y= multiple * x^2
     * 1/2 corresponds to y= multiple * x
     * 2/3 corresponds to y= multiple * x^1/2
     * multiple will depends on contract initialization,
     * specificallytotalAmount and poolBalance parameters
     * we might want to add an 'initialize' function that will allow
     * the owner to send ether to the contract and mint a given amount of tokens
     */
    uint32 public reserveRatio;

    event BCMinted(uint256 amountMinted, uint256 totalCost);
    event BCWithdrawn(uint256 amountWithdrawn, uint256 reward);

    /**
     * @dev Buy tokens
     * @param buyAmount the reserved tokens in
     * @param recipient the address receiving the purchase return
     * we assume that the contract already receive reserved token from the purchase
     */
    function _bcBuy(uint256 buyAmount, address recipient) internal returns(uint256) {
        require(buyAmount > 0);
        uint256 tokensToMint = calculatePurchaseReturn(
            totalSupply(),
            poolBalance,
            reserveRatio,
            buyAmount
        );
        _mint(recipient, tokensToMint);
        poolBalance = poolBalance + buyAmount;
        return tokensToMint;
    }

    /**
     * @dev Sell tokens
     * @param from saler of the token
     * @param sellAmount Amount of tokens to withdraw
     */
    function _bcSell(
        address from,
        uint256 sellAmount
    ) internal returns(uint256) {
        require(sellAmount > 0 && balanceOf(from) >= sellAmount);
        uint256 amountOut = calculateSaleReturn(
            totalSupply(),
            poolBalance,
            reserveRatio,
            sellAmount
        );
        _burn(from, sellAmount);
        poolBalance = poolBalance - amountOut;
        return amountOut;
    }
}
