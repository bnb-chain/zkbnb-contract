const {getDeployedAddresses, getZecreyLegendProxy} = require("./utils")
const {ethers} = require("hardhat");

async function main() {
    const addrs = getDeployedAddresses('info/addresses.json')
    const [owner] = await ethers.getSigners();
    const Token = await ethers.getContractFactory('ZecreyRelatedERC20')
    const LegToken = await Token.attach('0x1A9FEAc5793E4b34C679262aE5719957c4f4a76C')
    const ReyToken = await Token.attach('0xddfE4eD28c9CD5c7C0FCb756F02e786284213CAE')

    console.log('Transfer LEG')
    const recipient = '0x805e286d05388911ccdb10e3c7b9713415607c72'
    let transferTx = await LegToken.transfer(recipient, ethers.utils.parseEther('1000'))
    await transferTx.wait()
    console.log('Transfer REY')
    transferTx = await ReyToken.transfer(recipient, ethers.utils.parseEther('1000'))
    await transferTx.wait()

    console.log('Transfer BNB')
    transferTx = await owner.sendTransaction({
        to: recipient,
        value: ethers.utils.parseEther('10'),
    })
    await transferTx.wait()


}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('Error:', err.message || err);
        process.exit(1);
    });