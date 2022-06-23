require("@nomiclabs/hardhat-waffle");
require("hardhat-tracer");
require('@openzeppelin/hardhat-upgrades');
require('hardhat-contract-sizer')
require('hardhat-abi-exporter');
// require('hardhat-watcher');

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
            accounts: ['906d5dc5a8ec5050a21987278d42af90852724df53a576e66057990ee48ac269'],
            timeout: 100000,
        },
        BNBTest: {
            url: "http://tf-dex-preview-validator-nlb-6fd109ac8b9d390a.elb.ap-northeast-1.amazonaws.com:8545",
            accounts: ['107f9d2a50ce2d8337e0c5220574e9fcf2bf60002da5acf07718f4d531ea3faa'],
            timeout: 100000,
            gas: 6000000
        },
        BSCTestnet: {
            url: "http://tf-dex-preview-validator-nlb-6fd109ac8b9d390a.elb.ap-northeast-1.amazonaws.com:8545",
            accounts: ['107f9d2a50ce2d8337e0c5220574e9fcf2bf60002da5acf07718f4d531ea3faa'],
            timeout: 100000,
            gas: 6000000
        },
        testnet: {
            url: "https://data-seed-prebsc-2-s1.binance.org:8545",
            chainId: 97,
            accounts: ['740033b136ec1888b17e68b50c60c78ba7e1f61c8249497801a7f0fb796abb6b'],
            timeout: 100000,
            gas: 6000000
        }
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
        only: [':Governance$', ':Zkbas'],
        spacing: 2
    },
    // watcher: {
    //     compilation: {
    //         tasks: ["compile"],
    //         files: ["./contracts/ZkbasNFTFactory.sol"],
    //         verbose: true,
    //     }
    // },
};
