#!/bin/bash

# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

forge create src/PumpFactory.sol:PumpFactory \
--rpc-url $TESTNET_RPC_URL \
--private-key $TESTNET_DEPLOYER_PK \
--constructor-args 0x14679D1Da243B8c7d1A4c6d0523A2Ce614Ef027C $TESTNET_TOKEN_IMPLEMENTATION \
--legacy
