const {getDeployedAddresses, getZkbasProxy} = require("./utils")
const {ethers} = require("hardhat");

async function main() {
    const [owner] = await ethers.getSigners();
    const addrs = getDeployedAddresses('info/addresses.json')
    const zkbas = await getZkbasProxy(addrs.zkbasProxy)
    const Price = await ethers.getContractFactory('StablePriceOracle')
    const price = await Price.attach(addrs.znsPriceOracle)
    const treasuryName = 'treasury'
    const gasName = 'gas'
    const sherName = 'sher'
    const gavinName = 'gavin'
    const treasuryRegisterFee = await price.price(treasuryName)
    const gasRegisterFee = await price.price(gasName)
    const sherRegisterFee = await price.price(sherName)
    const gavinRegisterFee = await price.price(gavinName)


    console.log('Register ZNS for treasury, gas, sher and gavin...')
    let registerZnsTx = await zkbas.registerZNS(
        treasuryName,
        '0x56744Dc80a3a520F0cCABf083AC874a4bf6433F3',
        '0x2005db7af2bdcfae1fa8d28833ae2f1995e9a8e0825377cff121db64b0db21b7',
        '0x18a96ca582a72b16f464330c89ab73277cb96e42df105ebf5c9ac5330d47b8fc',
        {
            value: treasuryRegisterFee,
        }
    )
    await registerZnsTx.wait()
    registerZnsTx = await zkbas.registerZNS(
        gasName,
        '0x56744Dc80a3a520F0cCABf083AC874a4bf6433F3',
        '0x2c24415b75651673b0d7bbf145ac8d7cb744ba6926963d1d014836336df1317a',
        '0x134f4726b89983a8e7babbf6973e7ee16311e24328edf987bb0fbe7a494ec91e',
        {
            value: gasRegisterFee,
        }
    )
    await registerZnsTx.wait()
    registerZnsTx = await zkbas.registerZNS(
        sherName,
        // '0xE9b15a2D396B349ABF60e53ec66Bcf9af262D449', // BSC
        // '0x7dD2Ac589eFCC8888474d95Cb4b084CCa2d8aA57', // Local
        // '0x56744Dc80a3a520F0cCABf083AC874a4bf6433F3', // BNB Zecrey Test
        owner.address,
        '0x235fdbbbf5ef1665f3422211702126433c909487c456e594ef3a56910810396a',
        '0x05dde55c8adfb6689ead7f5610726afd5fd6ea35a3516dc68e57546146f7b6b0',
        {
            value: sherRegisterFee,
        }
    )
    await registerZnsTx.wait()
    registerZnsTx = await zkbas.registerZNS(
        gavinName,
        '0xf162Be50463c1EbFbf1A2eF944885945A768fbC1',
        '0x0649fef47f6cf3dfb767cf5599eea11677bb6495956ec4cf75707d3aca7c06ed',
        '0x0e07b60bf3a2bf5e1a355793498de43e4d8dac50b892528f9664a03ceacc0005',
        {
            value: gavinRegisterFee,
        }
    )
    await registerZnsTx.wait()
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('Error:', err.message || err);
        process.exit(1);
    });