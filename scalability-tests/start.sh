#!/bin/bash

DEPLOY_PATH=~/zkbnb-contract-scalability
KEY_PATH=~/.zkbnb-contract-scalability
REPO_PATH=$(pwd)

BLOCK_SIZE1=1
BLOCK_SIZE2=4
BLOCK_SIZE3=8
BLOCK_SIZE4=16


echo 'Remove and clone zkbnb-crypto'
export PATH=$PATH:/usr/local/go/bin/
cd ~ || exit
rm -rf ${DEPLOY_PATH}
mkdir -p ${DEPLOY_PATH} && cd ${DEPLOY_PATH} || exit
git clone --branch feature/diff-block-size https://github.com/ruslangm/zkbnb-crypto


echo "Started generating new PK/VK for various block sizes in parallel"
cd ${DEPLOY_PATH} || exit
cd zkbnb-crypto || exit
go test ./circuit/solidity -timeout 99999s -run TestExportSol -blocksize=${BLOCK_SIZE1} &
go test ./circuit/solidity -timeout 99999s -run TestExportSol -blocksize=${BLOCK_SIZE2} &
go test ./circuit/solidity -timeout 99999s -run TestExportSol -blocksize=${BLOCK_SIZE3} &
go test ./circuit/solidity -timeout 99999s -run TestExportSol -blocksize=${BLOCK_SIZE4} &
wait
cd ${DEPLOY_PATH} || exit
mkdir -p $KEY_PATH
cp -r ./zkbnb-crypto/circuit/solidity/* $KEY_PATH


echo "Copying the Verification keys to ZkBNBVerifier contract"
cd ${REPO_PATH} || exit
args=(
${KEY_PATH}/ZkBNBVerifier${BLOCK_SIZE1}.sol ${KEY_PATH}/ZkBNBVerifier${BLOCK_SIZE2}.sol ${KEY_PATH}/ZkBNBVerifier${BLOCK_SIZE3}.sol ${KEY_PATH}/ZkBNBVerifier${BLOCK_SIZE4}.sol
${BLOCK_SIZE1} ${BLOCK_SIZE2} ${BLOCK_SIZE3} ${BLOCK_SIZE4}
../contracts/ZkBNBVerifier.sol
)
python3 verifier_parse.py "${args[@]}"