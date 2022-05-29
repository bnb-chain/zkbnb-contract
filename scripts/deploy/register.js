const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')
const {getDeployedAddresses, getZecreyLegendProxy} = require("./utils")

async function main() {
    const addrs = getDeployedAddresses('info/addresses.json')
    const zecreyLegend = await getZecreyLegendProxy(addrs.zecreyLegendProxy)

    console.log('Register ZNS for treasury, gas, sher and gavin...')
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
        '0x677d65A350c9FB84b14bDDF591043eb8243960D1',
        '0x63c4c6aff36c8ef69f6fb8e217930722c5d8819c3a30db783c54f8d94a2b2b2d')
    await registerZnsTx.wait()
    registerZnsTx = await zecreyLegend.registerZNS(
        'gavin',
        '0xf162Be50463c1EbFbf1A2eF944885945A768fbC1',
        '0x3eea11654758743beaf11610b88e739ba6c126f0bd39880c279ee633eb615b8c')
    await registerZnsTx.wait()

    const hashVal = namehash.hash('gavin.legend');
    const addr = await zecreyLegend.getAddressByAccountNameHash(hashVal)
    console.log('Gavin address: ', addr)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('Error:', err.message || err);
        process.exit(1);
    });