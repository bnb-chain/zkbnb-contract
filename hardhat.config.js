require("@nomiclabs/hardhat-waffle");
require("hardhat-tracer");
require('@openzeppelin/hardhat-upgrades');

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    networks: {
        hardhat: {},
        local: {
            url: "http://127.0.0.1:8545",
            accounts: ['acbaa269bd7573ff12361be4b97201aef019776ea13384681d4e5ba6a88367d9'],
            timeout: 100000
        }
    },
    solidity: {
        version: "0.7.6",
        settings: {
            optimizer: {
                enabled: true,
                runs: 1000,
            },
        },
    },
};
