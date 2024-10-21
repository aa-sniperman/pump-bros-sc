#!/bin/bash

# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

forge create src/PumpFactory.sol:PumpFactory \
--rpc-url $TESTNET_RPC_URL \
--private-key $TESTNET_DEPLOYER_PK \
--constructor-args $TESTNET_UNISWAPV2_ROUTER $TESTNET_TOKEN_IMPLEMENTATION \
--legacy
