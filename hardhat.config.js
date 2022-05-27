require("@nomiclabs/hardhat-waffle");
require("hardhat-tracer");
require('@openzeppelin/hardhat-upgrades');
// require('hardhat-contract-sizer')
require('hardhat-abi-exporter');

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
            accounts: ['ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'],
            timeout: 100000,
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
    abiExporter: {
        path: './data/abi',
        clear: true,
        flat: true,
        only: [':ZecreyLegend$'],
        spacing: 2
    }
};
