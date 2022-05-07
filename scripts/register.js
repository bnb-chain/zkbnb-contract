const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')

const zecreyLegendAddr = '0xe7112456F5f54D642097dae24c695Ad1130dfd4B'
const utilsAddr = '0xdA634D1f99a50d9A59E6C1e7604B4e8274AADF34'

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
        '0x6788fdbc635cf86e266853a628b2743643df5c1db1a4f9afbb13bca103322e9a')
    await registerZnsTx.wait()
    registerZnsTx = await zecreyLegend.registerZNS('gavin',
        '0xd5Aa3B56a2E2139DB315CdFE3b34149c8ed09171',
        '0xc47ae844d054fa24fb27d18cd9ff5c99df93aab03c389d8d4a292c54f44a320b')
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