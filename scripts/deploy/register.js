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
        '0x412805eb224e8c10de9ee037f55c92f32266f057fad3279cf4bab0a49d8f4080')
    await registerZnsTx.wait()
    registerZnsTx = await zecreyLegend.registerZNS(
        'gas',
        '0xcf539790352c4036496e66Aabc5EE1fE8c91016C',
        '0x53aa127ef258d5311bb9d8736d087e1c81204d356f876e7c42c42befcd679827')
    await registerZnsTx.wait()
    registerZnsTx = await zecreyLegend.registerZNS(
        'sher',
        '0x677d65A350c9FB84b14bDDF591043eb8243960D1',
        '0x7f70064f2c485996dc2acb397d0b4fe63eec854aad09b6fd3c41549e6d046586')
    await registerZnsTx.wait()
    registerZnsTx = await zecreyLegend.registerZNS(
        'gavin',
        '0xf162Be50463c1EbFbf1A2eF944885945A768fbC1',
        '0xc9e9ccb618f4825496506f70551d725dec7aeb2e3f31da262ea45ab88a174909')
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