import { HardhatUserConfig } from 'hardhat/config';

import 'hardhat-tracer';
import '@openzeppelin/hardhat-upgrades';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-gas-reporter';
import 'hardhat-contract-sizer';

import * as dotenv from 'dotenv';

dotenv.config();
const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.17',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      modelChecker: {
        engine: 'chc',
        divModNoSlacks: true,
        showUnproved: true,
        contracts: {
          'contracts/ZkBNBNFTFactory.sol': ['ZkBNBNFTFactory'],
          'contracts/ZkBNB.sol': ['ZkBNB'],
          'contracts/Governance.sol': ['Governance'],
        },
        invariants: ['contract', 'reentrancy'],
        targets: [
          'assert',
          'underflow',
          'overflow',
          'divByZero',
          'constantCondition',
          'popEmptyArray',
          'outOfBounds',
          'balance',
        ],
        timeout: 20000,
      },
      outputSelection: {
        '*': {
          '*': ['storageLayout'],
        },
      },
    },
  },
  paths: {
    root: '../',
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      accounts: {
        accountsBalance: '10000000000000000000000000000000000000000',
      },
    },
  },
};

export default config;
