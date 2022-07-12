const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')
const {getDeployedAddresses, getZecreyLegendProxy} = require("./utils");

async function main() {
    const addrs = getDeployedAddresses('info/addresses.json')
    const zecreyLegend = await getZecreyLegendProxy(addrs.zecreyLegendProxy)

    // create pairs
    console.log('createPair...')
    let createPairTx = await zecreyLegend.createPair('0x0000000000000000000000000000000000000000', addrs.REYToken)
    await createPairTx.wait()
    createPairTx = await zecreyLegend.createPair('0x0000000000000000000000000000000000000000', addrs.LEGToken)
    await createPairTx.wait()
    createPairTx = await zecreyLegend.createPair(addrs.REYToken, addrs.LEGToken)
    await createPairTx.wait()
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('Error:', err.message || err);
        process.exit(1);
    });