const {getDeployedAddresses, getZecreyLegendProxy} = require("./utils")
const {ethers} = require("hardhat");

async function main() {
    const addrs = getDeployedAddresses('info/addresses.json')
    const Token = await ethers.getContractFactory('ZecreyRelatedERC20')
    const token = await Token.attach('0x405c41BE630e29f4f6D12bcF6Bf81f7A988e3385')

    console.log('Transfer LEG')
    const recipient = '0x805e286D05388911cCdB10E3c7b9713415607c72'
    const transferTx = await token.transfer(recipient, ethers.utils.parseEther('1000'))
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