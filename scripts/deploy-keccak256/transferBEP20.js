const {getDeployedAddresses, getZecreyLegendProxy} = require("./utils")
const {ethers} = require("hardhat");

async function main() {
    const addrs = getDeployedAddresses('info/addresses.json')
    const [owner] = await ethers.getSigners();
    const Token = await ethers.getContractFactory('ZecreyRelatedERC20')
    const LegToken = await Token.attach(addrs.LEGToken)
    const ReyToken = await Token.attach(addrs.REYToken)

    console.log('Transfer LEG')
    const recipient = '0x736B2D2A88e576F9204e93B256BAAb48d0c35b3D'
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