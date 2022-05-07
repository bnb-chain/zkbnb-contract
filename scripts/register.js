const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')

const zecreyLegendAddr = '0x9bFE5149E86Cd8A47DddB82b7800813d5A3adab6'
const utilsAddr = '0x0D3014961da0f9603Dee59B63c703eA6202AD480'

async function main() {
    // zecrey legend
    const ZecreyLegend = await ethers.getContractFactory('ZecreyLegend', {
        libraries: {
            Utils: utilsAddr
        }
    });
    const zecreyLegend = await ZecreyLegend.attach(zecreyLegendAddr)
    // seed = d892d866c5d0569e39e23c7bd46d63373d95197483e1a9af491e7098913a39ac
    var registerZnsTx = await zecreyLegend.registerZNS(
        'sher',
        '0xDA00601380Bc7aE4fe67dA2EB78f9161570c9EB4',
        '0x63c4c6aff36c8ef69f6fb8e217930722c5d8819c3a30db783c54f8d94a2b2b2d')
    await registerZnsTx.wait()
    registerZnsTx = await zecreyLegend.registerZNS('gavin',
        '0xd5Aa3B56a2E2139DB315CdFE3b34149c8ed09171',
        '0x3eea11654758743beaf11610b88e739ba6c126f0bd39880c279ee633eb615b8c')
    await registerZnsTx.wait()

    const hashVal = namehash.hash('gavin.legend');
    const addr = await zecreyLegend.getAddressByAccountNameHash(hashVal)
    console.log('addr:', addr)
}

// get the keccak256 hash of a specified string name
// eg: getKeccak256('zecrey') = '0x621eacce7c1f02dbf62859801a97d1b2903abc1c3e00e28acfb32cdac01ab36d'
const getKeccak256 = (name) => {
    return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name))
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });