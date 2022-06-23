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
            accounts: ['08e504b8a5fd5bbc41e953f6e9cbe3371661c0010767c09315ace07e5a1e938e'],
            timeout: 100000,
        },
        BNBTest: {
            url: "http://tf-dex-preview-validator-nlb-6fd109ac8b9d390a.elb.ap-northeast-1.amazonaws.com:8545",
            accounts: ['107f9d2a50ce2d8337e0c5220574e9fcf2bf60002da5acf07718f4d531ea3faa'],
            timeout: 100000,
            gas: 15000000
        },
        BSCTestnet: {
            url: "https://data-seed-prebsc-2-s2.binance.org:8545",
            accounts: ['acbaa269bd7573ff12361be4b97201aef019776ea13384681d4e5ba6a88367d9'],
            timeout: 300000,
            gas: 15000000
        },
        avalanche_fuji: {
            url: "https://api.avax-test.network/ext/bc/C/rpc",
            accounts: ['acbaa269bd7573ff12361be4b97201aef019776ea13384681d4e5ba6a88367d9'],
            timeout: 100000,
            gas: 15000000,
        },
        polygon_mumbai: {
            url: "https://polygon-mumbai.g.alchemy.com/v2/O2mVU_nX6p-nnrTFKqASBQi74hsxCsro",
            accounts: ['acbaa269bd7573ff12361be4b97201aef019776ea13384681d4e5ba6a88367d9'],
            timeout: 100000,
            gas: 10000000,
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
        only: [':OldZecreyLegend'],
        spacing: 2
    },
    // watcher: {
    //     compilation: {
    //         tasks: ["compile"],
    //         files: ["./contracts/ZecreyNFTFactory.sol"],
    //         verbose: true,
    //     }
    // },
};
