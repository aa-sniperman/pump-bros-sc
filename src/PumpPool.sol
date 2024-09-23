// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20;

import "./BondingCurve.sol";

contract PumpPool is BondingCurve {

  uint16 private constant FEE_BPS = 500; // 5% in basis point

  uint16 private constant USER_HOLDING_PUMP_THRESHOLD = 5100; // 51% 

  uint256 private constant MAX_TOTAL_SUPPLY = 1e9;


  function initialize(
    string memory name_,
    string memory symbol_,
    uint32 reserveRatio_
  ) external initializer {
    __ERC20_init(name_, symbol_);
    reserveRatio = reserveRatio_;
  }


}