const fs = require('fs')
const {ethers} = require("hardhat");

// Read deployed addresses from file
exports.getDeployedAddresses = function (path) {
    const raw = fs.readFileSync(path);
    return JSON.parse(raw);
}

// Write deployed addresses to json file
exports.saveDeployedAddresses = function (path, addrs) {
    let data = JSON.stringify(addrs, null, 2);
    fs.writeFileSync(path, data);
}

exports.getZkbasProxy = async function (addr) {
    // Get utils contract
    const Utils = await ethers.getContractFactory("Utils")
    const utils = await Utils.deploy()
    await utils.deployed()

    // zkbas
    const Zkbas = await ethers.getContractFactory('OldZkbas', {
        libraries: {
            Utils: utils.address
        }
    });

    return Zkbas.attach(addr);
}

// Get the keccak256 hash of a specified string name
// eg: getKeccak256('zkbas') = '0x621eacce7c1f02dbf62859801a97d1b2903abc1c3e00e28acfb32cdac01ab36d'
exports.getKeccak256 = function (name) {
    return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name))
}