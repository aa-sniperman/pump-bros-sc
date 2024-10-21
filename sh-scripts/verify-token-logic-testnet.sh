#!/bin/bash

# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

forge verify-contract $TESTNET_TOKEN_IMPLEMENTATION src/PumpToken.sol:PumpToken \
--etherscan-api-key $TESTNET_API_KEY \
--verifier-url $TESTNET_VERIFY_URL \
--constructor-args $(cast abi-encode "constructor()") --watch