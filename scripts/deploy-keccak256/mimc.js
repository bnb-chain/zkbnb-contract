const {ethers} = require("hardhat");

async function main() {
    const [owner] = await ethers.getSigners();

    const contractFactories = await getContractFactories()

    console.log('Deploy ZNS registry...')
    const znsRegistry = await contractFactories.ZNSRegistry.deploy();
    await znsRegistry.deployed();

    console.log('Register ZNS base node...')
    const rootNode =      '0x0000000000000000000000000000000000000000000000000000000000000000'
    const baseNodeLabel = '0x281aceaf4771e7fba770453ce3ed74983a7343be68063ea7d50ab05c1b8ef751'         // mimc('legend');
    const setBaseNodeTx = await znsRegistry.connect(owner).setSubnodeOwner(rootNode, baseNodeLabel, owner.address, ethers.constants.HashZero);
    await setBaseNodeTx.wait();
}

async function getContractFactories() {
    const Utils = await ethers.getContractFactory("Utils")
    const utils = await Utils.deploy()
    await utils.deployed()

    return {
        TokenFactory: await ethers.getContractFactory('ZecreyRelatedERC20'),
        ERC721Factory: await ethers.getContractFactory('ZecreyRelatedERC721'),
        ZNSRegistry: await ethers.getContractFactory('ZNSRegistry'),
        ZNSResolver: await ethers.getContractFactory('PublicResolver'),
        ZNSPriceOracle: await ethers.getContractFactory('StablePriceOracle'),
        ZNSController: await ethers.getContractFactory('ZNSController'),
        Governance: await ethers.getContractFactory('Governance'),
        AssetGovernance: await ethers.getContractFactory('AssetGovernance'),
        Verifier: await ethers.getContractFactory('ZecreyVerifier'),
        ZecreyLegend: await ethers.getContractFactory('ZecreyLegend', {
            libraries: {
                Utils: utils.address
            }
        }),
        DeployFactory: await ethers.getContractFactory('DeployFactory')
    }
}

main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('Error:', err.message || err);
        process.exit(1);
    });