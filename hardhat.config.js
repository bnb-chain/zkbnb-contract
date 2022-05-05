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
            accounts: ['a36902d14b35e3ed9a288bebd513baa77b3772c6263d6fefff70fadf12fe097a'],
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
