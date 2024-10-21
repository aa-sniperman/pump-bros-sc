#!/bin/bash

# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

forge verify-contract $TESTNET_FACTORY src/PumpFactory.sol:PumpFactory \
--etherscan-api-key $TESTNET_API_KEY \
--verifier-url $TESTNET_VERIFY_URL \
--constructor-args $(cast abi-encode "constructor(address, address)" $TESTNET_UNISWAPV2_ROUTER $TESTNET_TOKEN_IMPLEMENTATION) --watch