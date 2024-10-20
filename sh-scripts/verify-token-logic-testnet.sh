#!/bin/bash

# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

forge verify-contract $TESTNET_TOKEN_IMPLEMENTATION src/PumpToken.sol:PumpToken \
--chain-id 59902 \
--verifier sourcify \
--constructor-args $(cast abi-encode "constructor()") --watch