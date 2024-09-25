// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library SafeMath {
  function safeMinus(uint256 a, uint256 b) internal pure returns (uint256){
    return a < b ? 0 : a - b;
  }
}