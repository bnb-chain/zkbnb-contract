const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')

const REYBEP20Addr = '0xb0Eb8D52c7760B0F76a015443bB5367600ed627D'
const LEGBEP20Addr = '0x01531005834e4fEB117957eBd9Dee6AAf78a6153'
const zecreyLegendAddr = '0xB0fE6AE96Db933140551b03c731043B502EAd393'
const utilsAddr = '0xc92d4a9Ee676744eD6edDff7Fd70ABf47F822846'

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
        'treasury',
        '0x49D35436e9B460275Bd927CAFCcEaEc8223cb84c',
        '0x0648bf303726d039c22588f9c6b63558a3ea07d845f35ce833909ba8611db9ab')
    await registerZnsTx.wait()
    registerZnsTx = await zecreyLegend.registerZNS(
        'gas',
        '0xcf539790352c4036496e66Aabc5EE1fE8c91016C',
        '0x7b12ba6af32bba6e55fb4f49c224eb73f379c5cffabfd68d8df4f58b0c0b5d18')
    await registerZnsTx.wait()
    registerZnsTx = await zecreyLegend.registerZNS(
        'sher',
        '0xDA00601380Bc7aE4fe67dA2EB78f9161570c9EB4',
        '0x63c4c6aff36c8ef69f6fb8e217930722c5d8819c3a30db783c54f8d94a2b2b2d')
    await registerZnsTx.wait()
    registerZnsTx = await zecreyLegend.registerZNS(
        'gavin',
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