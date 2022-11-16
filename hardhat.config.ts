import {HardhatUserConfig} from "hardhat/config";

import "hardhat-tracer"
import '@openzeppelin/hardhat-upgrades'
import 'hardhat-contract-sizer'
import 'hardhat-abi-exporter'
import '@nomiclabs/hardhat-ethers'
import '@typechain/hardhat'
import '@nomiclabs/hardhat-waffle'
import * as dotenv from 'dotenv'
dotenv.config()


const getAccounts = (privateKeys: string | undefined): Array<string> => {
    if (!privateKeys) {
        return []
    }

    const privateKeyArr = privateKeys.split(',')
    return privateKeyArr
        .filter((privateKey) => {
            // Filter empty strings, no empty strings should occupy array positions
            return privateKey.trim().length > 0
        })
        .map((privateKey) => {
            const tempPrivateKey = privateKey.trim()
            if (tempPrivateKey.startsWith('0x')) {
                return tempPrivateKey
            }
            return `0x${tempPrivateKey}`
        })
}

const COMPILER_SETTINGS = {
    optimizer: {
        enabled: true,
        runs: 1000,
    },
}

const config: HardhatUserConfig = {
    solidity: {
        version: "0.7.6",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
    defaultNetwork: 'BSCTestnet',
    networks: {
        // hardhat: {
        //     allowUnlimitedContractSize: true,
        // },
        local: {
            url: process.env.LOCAL_RPC || "http://127.0.0.1:8545",
            accounts: (process.env.LOCAL_PRIVATE_KEY || '0xabc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abc1').split(','),
            timeout: 100000,
        },
        BSCTestnet: {
            url: process.env.BSC_TESTNET_RPC || "https://data-seed-prebsc-1-s1.binance.org:8545",
            accounts: (process.env.BSC_TESTNET_PRIVATE_KEY || '0xabc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abc1').split(','),
            timeout: 300000,
            gas: 15000000
        },
    },
}

export default config

// module.exports = {
//
//     // contractSizer: {
//     //     alphaSort: true,
//     //     disambiguatePaths: false,
//     //     runOnCompile: true,
//     //     strict: true,
//     // },
//     abiExporter: {
//         path: './data/abi',
//         clear: true,
//         flat: true,
//         only: [':Governance$', ':ZkBNB', ':StablePriceOracle'],
//         spacing: 2
//     },
// };
