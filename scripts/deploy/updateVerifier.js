const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')
const {getDeployedAddresses, getZkbasProxy} = require("./utils");

async function main() {
    const addrs = getDeployedAddresses('info/addresses.json')
    const zkbas = await getZkbasProxy(addrs.zkbasProxy)

    console.log('Prepare new ZkbasVerifier')
    // new verifier
    const NewVerifier = await ethers.getContractFactory('ZkbasVerifier')
    console.log('Deploy New Verifier...')
    const newVerifier = await NewVerifier.deploy()
    await newVerifier.deployed()
    console.log('Deploy Proxy for NewVerifier...')
    const Proxy = await ethers.getContractFactory('Proxy')
    const newVerifierProxy = await Proxy.deploy(newVerifier.address, [])
    await newVerifierProxy.deployed()

    // update verifier
    console.log('Update Verifier...')
    let updateVerifierTx = await zkbas.updateZkbasVerifier(newVerifierProxy.address)
    await updateVerifierTx.wait()
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('Error:', err.message || err);
        process.exit(1);
    });