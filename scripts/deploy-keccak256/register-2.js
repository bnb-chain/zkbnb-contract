const {getDeployedAddresses, getZecreyLegendProxy} = require("./utils")

async function main() {
    const addrs = getDeployedAddresses('info/addresses.json')
    const zecreyLegend = await getZecreyLegendProxy(addrs.zecreyLegendProxy)

    console.log('Register ZNS for test...')
    let registerZnsTx = await zecreyLegend.registerZNS(
        'test',
        '0x09E45d6FcF322c4D93E6aFE7076601FF10BA942E',
        '0x0c3f61c6e7f9b215b0ecdb1091fe9063d74e6e59e2928a5f731e751ff816071a',
        '0x27b23075df7bcc8747550e6802ade0459aaf06d5c115d84eb0bf0a7042e46fd5',
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