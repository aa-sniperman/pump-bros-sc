#!/bin/bash

# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

forge create src/PumpToken.sol:PumpToken \
--rpc-url $TESTNET_RPC_URL \
--private-key $TESTNET_DEPLOYER_PK \
--legacy