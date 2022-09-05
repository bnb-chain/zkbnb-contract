require("@nomiclabs/hardhat-waffle");
require("hardhat-tracer");
require('@openzeppelin/hardhat-upgrades');
require('hardhat-contract-sizer')
require('hardhat-abi-exporter');
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
            url: "http://127.0.0.1:8545",
            accounts: [
                '906d5dc5a8ec5050a21987278d42af90852724df53a576e66057990ee48ac269'
            ],
            timeout: 100000,
        },
        BSCTestnet: {
            url: "https://data-seed-prebsc-1-s1.binance.org:8545",
            accounts: [
                process.env.BSC_TESTNET_PRIVATE_KEY || '906d5dc5a8ec5050a21987278d42af90852724df53a576e66057990ee48ac269'
            ],
            timeout: 300000,
            gas: 15000000
        },
    },
    solidity: {
        version: "0.7.6",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
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
        spacing: 2
    },
};
