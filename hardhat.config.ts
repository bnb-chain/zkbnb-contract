import { HardhatUserConfig } from 'hardhat/config';

import 'hardhat-tracer';
import '@openzeppelin/hardhat-upgrades';
import 'hardhat-abi-exporter';
import 'solidity-coverage';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-gas-reporter';
import 'hardhat-contract-sizer';

import * as dotenv from 'dotenv';

dotenv.config();

const config: HardhatUserConfig = {
  etherscan: {
    // Your API key for BSC. Obtain one at https://bscscan.com/
    apiKey: {
      bscTestnet: process.env.BSCSCAN_APIKEY || '00000000000000000000000000000000000000000',
      bsc: process.env.BSCSCAN_API_KEY || '00000000000000000000000000000000000000000',
    },
  },
  solidity: {
    version: '0.8.17',
    settings: {
      optimizer: {
        enabled: true,
        runs: 1500,
      },
      outputSelection: {
        '*': {
          '*': ['storageLayout'],
        },
      },
    },
  },
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      accounts: {
        accountsBalance: '10000000000000000000000000000000000000000',
      },
    },
    local: {
      url: process.env.LOCAL_RPC || 'http://127.0.0.1:8545',
      accounts: (
        process.env.LOCAL_PRIVATE_KEY || '0xabc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abc1'
      ).split(','),
      timeout: 100000,
    },
    BSCTestnet: {
      url: process.env.BSC_TESTNET_RPC || 'https://data-seed-prebsc-1-s1.binance.org:8545',
      accounts: (
        process.env.BSC_TESTNET_PRIVATE_KEY || '0xabc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abc1'
      ).split(','),
      timeout: 300000,
      gas: 1500000,
    },
    BSCMainnet: {
      url: process.env.BSC_MAINNET_RPC || 'https://bsc-dataseed.binance.org',
      accounts: (
        process.env.BSC_MAINNET_PRIVATE_KEY || '0xabc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abc1'
      ).split(','),
      timeout: 300000,
      gas: 1500000,
    },
  },
  abiExporter: {
    path: './abi',
    clear: true,
    flat: true,
    only: [':Governance$', ':ZkBNB', ':StablePriceOracle'],
    spacing: 2,
  },
};

export default config;
