const {ethers} = require("hardhat");
const fs = require('fs')

async function main() {
    const [owner] = await ethers.getSigners();
    const governor = owner.address;

    const contractFactories = await getContractFactories()

    // deploy new zecrey contract
    console.log('Deploy ZecreyLegend...')
    const zecreyLegend = await contractFactories.ZecreyLegend.deploy()
    await zecreyLegend.deployed()

    console.log('zecreyLegend new impl:', zecreyLegend.address)

    // --- main upgrade workflow ---
    const gatekeeper = await ethers.getContractAt('UpgradeGatekeeper', '0x8a3c077C33F8b7f54FEc08dB46F24C6988b29e99')

    // start upgrade
    let newTarget = [
        ethers.constants.AddressZero,  // 0
        ethers.constants.AddressZero,  // 1
        ethers.constants.AddressZero,  // 2
        ethers.constants.AddressZero,  // 3
        zecreyLegend.address,  // 4
    ]
    let tx5 = await gatekeeper.connect(owner).startUpgrade(newTarget)
    await tx5.wait()
    console.log('finish startUpgrade')

    // start preparation
    let tx6 = await gatekeeper.connect(owner).startPreparation()
    await tx6.wait()
    console.log('finish start preparation')

    // finish upgrade
    let tx7 = await gatekeeper.connect(owner).finishUpgrade([[],[]])
    await tx7.wait()
    console.log('finish upgrade')
}

async function getContractFactories() {
    const Utils = await ethers.getContractFactory("Utils")
    const utils = await Utils.deploy()
    await utils.deployed()

    return {
        TokenFactory: await ethers.getContractFactory('ZecreyRelatedERC20'),
        ERC721Factory: await ethers.getContractFactory('ZecreyRelatedERC721'),
        ZNSRegistry: await ethers.getContractFactory('OldZNSRegistry'),
        ZNSResolver: await ethers.getContractFactory('PublicResolver'),
        ZNSPriceOracle: await ethers.getContractFactory('StablePriceOracle'),
        ZNSController: await ethers.getContractFactory('OldZNSController'),
        Governance: await ethers.getContractFactory('Governance'),
        AssetGovernance: await ethers.getContractFactory('AssetGovernance'),
        Verifier: await ethers.getContractFactory('ZecreyVerifier'),
        ZecreyLegend: await ethers.getContractFactory('OldZecreyLegend', {
            libraries: {
                Utils: utils.address
            }
        }),
        DeployFactory: await ethers.getContractFactory('DeployFactory'),
        DefaultNftFactory: await ethers.getContractFactory('ZecreyNFTFactory'),
    }
}

main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('Error:', err.message || err);
        process.exit(1);
    });

