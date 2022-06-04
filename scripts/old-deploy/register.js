const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')

const LEGBEP20Addr = '0xd6eE09FD4D75c46055eCA73F16EE0019610a4af0'
const REYBEP20Addr = '0x3e026C07eeCb70a096946194c62922DEd4b096a1'
const zecreyLegendAddr = '0xCb7cCE2D359CDAc59b59DB91EF5bFE9C5328730f'
const utilsAddr = '0x22c356b3E356f327E89328CB693CE9697c7148dB'

async function main() {
    // zecrey legend
    const ZecreyLegend = await ethers.getContractFactory('ZecreyLegend', {
        libraries: {
            Utils: utilsAddr
        }
    });
    const zecreyLegend = await ZecreyLegend.attach(zecreyLegendAddr)
    // seed = d892d866c5d0569e39e23c7bd46d63373d95197483e1a9af491e7098913a39ac
    let registerZnsTx = await zecreyLegend.registerZNS(
        'treasury',
        '0x56744Dc80a3a520F0cCABf083AC874a4bf6433F3',
        '0x199dbf795e1c6a289f74e6928b7e49b31d28fda5583f7b17569ec99dcc5df791',
        '0x00408f9da4b0baf49c27d3fa57f06622f3925cf537e09ede108c4e22eb052841',
    )
    await registerZnsTx.wait()
    registerZnsTx = await zecreyLegend.registerZNS(
        'gas',
        '0x56744Dc80a3a520F0cCABf083AC874a4bf6433F3',
        '0x0f946ae172f0c48c291587fc0b766d3009a69f634bb91af5d802e714459b1c55',
        '0x279867cdef2bc4427c6e876f354d20811c7e086d73d8b91b31d558f27e12aa53',
    )
    await registerZnsTx.wait()
    registerZnsTx = await zecreyLegend.registerZNS(
        'sher',
        '0x677d65A350c9FB84b14bDDF591043eb8243960D1',
        '0x1a2d662dc013bf75926e7ac1ef6210dba5e518a5e9bde689297a3bd8d4f1236e',
        '0x0665046d9e54413cfdb609ad4a85ec3ee64f0b7d39cb2adc9659482c4f06707f',
    )
    await registerZnsTx.wait()
    registerZnsTx = await zecreyLegend.registerZNS(
        'gavin',
        '0xf162Be50463c1EbFbf1A2eF944885945A768fbC1',
        '0x1739c8dc2bcad851a36984e065884d51bfa4192c7c2e6a25f1510636dc4753af',
        '0x0949178ab85aa42e26da313f2eeb7aec5d721d55706f50965482f418b6cce9c9',
    )
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