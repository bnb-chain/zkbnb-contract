@echo off
solcjs --abi --bin --optimize --base-path . ./ZecreyVerifier.sol && solcjs --abi --bin --optimize --base-path . ./Governance.sol && solcjs --abi --bin --optimize --base-path . ./AssetGovernance.sol && solcjs --abi --bin --optimize --base-path . ./ZecreyLegend.sol && solcjs --abi --bin --optimize --base-path . ./ZNSFIFSRegistrar.sol && solcjs --abi --bin --optimize --base-path . ./ZNSRegistry.sol && solcjs --abi --bin --optimize --base-path . ./MyERC20.sol

yarn run hardhat export-abi
yarn run hardhat clear-abi