#!/bin/bash

# Load environment variables from .env file
export $(grep -v '^#' .env | xargs)

TOKEN_NAME=$1
TOKEN_SYMBOL=$2

# deploy token using token factory
forge script script/CreatePumpToken.s.sol \
--private-key $TESTNET_DEPLOYER_PK \
--rpc-url $TESTNET_RPC_URL \
--sig "run(address, string, string)" $TESTNET_FACTORY $TOKEN_NAME $TOKEN_SYMBOL \
--legacy \
--broadcast