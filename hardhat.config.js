require('@nomiclabs/hardhat-waffle');
require('hardhat-tracer');
require('@openzeppelin/hardhat-upgrades');
require('hardhat-contract-sizer');
require('hardhat-abi-exporter');
require('solidity-coverage');

require('dotenv').config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  networks: {
    // hardhat: {
    //     allowUnlimitedContractSize: true,
    // },
    local: {
      url: process.env.LOCAL_RPC || 'http://127.0.0.1:8545',
      accounts: (
        process.env.LOCAL_PRIVATE_KEY ||
        '0xabc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abc1'
      ).split(','),
      timeout: 100000,
    },
    BSCTestnet: {
      url:
        process.env.BSC_TESTNET_RPC ||
        'https://data-seed-prebsc-1-s1.binance.org:8545',
      accounts: (
        process.env.BSC_TESTNET_PRIVATE_KEY ||
        '0xabc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abc1'
      ).split(','),
      timeout: 300000,
      gas: 15000000,
    },
  },
  solidity: {
    version: '0.7.6',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      outputSelection: {
        '*': {
          '*': ['storageLayout'],
        },
      },
    },
  },
  // contractSizer: {
  //     alphaSort: true,
  //     disambiguatePaths: false,
  //     runOnCompile: true,
  //     strict: true,
  // },

  abiExporter: {
    path: './data/abi',
    clear: true,
    flat: true,
    only: [':Governance$', ':ZkBNB', ':StablePriceOracle'],
    spacing: 2,
  },
};
