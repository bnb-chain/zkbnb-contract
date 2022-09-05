const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')
const {getDeployedAddresses, getZkBNBProxy} = require("./utils");

async function main() {
    const addrs = getDeployedAddresses('info/addresses.json')
    const zkbnb = await getZkBNBProxy(addrs.zkbnbProxy)

    // create pairs
    console.log('createPair...')
    let createPairTx = await zkbnb.createPair('0x0000000000000000000000000000000000000000', addrs.REYToken)
    await createPairTx.wait()
    createPairTx = await zkbnb.createPair('0x0000000000000000000000000000000000000000', addrs.LEGToken)
    await createPairTx.wait()
    createPairTx = await zkbnb.createPair(addrs.REYToken, addrs.LEGToken)
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
