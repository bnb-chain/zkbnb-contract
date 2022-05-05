const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')

async function main() {
    // zecrey legend
    const ZecreyLegend = await ethers.getContractFactory('ZecreyLegend', {
        libraries: {
            Utils: '0x8551137131D2D01a2d960ffeCE9079c4a282bCc7'
        }
    });
    const zecreyLegend = await ZecreyLegend.attach('0x7FEbE2f07e445b0684d5eA1C9dF8910dBCf9D526')
    // seed = d892d866c5d0569e39e23c7bd46d63373d95197483e1a9af491e7098913a39ac
    const registerZnsTx = await zecreyLegend.registerZNS(
        'sher',
        '0xDA00601380Bc7aE4fe67dA2EB78f9161570c9EB4',
        '0x6788fdbc635cf86e266853a628b2743643df5c1db1a4f9afbb13bca103322e9a')
    await registerZnsTx.wait()
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