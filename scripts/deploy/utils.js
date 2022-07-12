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

exports.getZecreyLegendProxy = async function (addr) {
    // Get utils contract
    const Utils = await ethers.getContractFactory("Utils")
    const utils = await Utils.deploy()
    await utils.deployed()

    // zecrey legend
    const ZecreyLegend = await ethers.getContractFactory('ZecreyLegend', {
        libraries: {
            Utils: utils.address
        }
    });

    return ZecreyLegend.attach(addr);
}