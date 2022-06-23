const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')
const {getDeployedAddresses, getZkbasProxy} = require("./utils");

async function main() {
    const addrs = getDeployedAddresses('info/addresses.json')
    const zkbas = await getZkbasProxy(addrs.zkbasProxy)

    // Update pair
    console.log('update pair rate...')
    const updatePairRateTx = await zkbas.updatePairRate(['0x0000000000000000000000000000000000000000', addrs.LEGToken, 50, 0, 10])
    await updatePairRateTx.wait()
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('Error:', err.message || err);
        process.exit(1);
    });