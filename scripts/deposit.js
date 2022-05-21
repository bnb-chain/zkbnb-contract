const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')
const {expect} = require("chai");

const REYBEP20Addr = '0xf4594B4438bebC738380c7106D06Cfb4BD6900e6'
const LEGBEP20Addr = '0xD448121586875996cfb7e0E65d44361e2F6bD6c0'
const zecreyLegendAddr = '0x700A9288d64e9994eF29CA09BE857A6d831850B4'
const utilsAddr = '0xB317C7D6763F64aBd871E3B75850e572d552606f'

async function main() {
    // zecrey legend
    const ZecreyLegend = await ethers.getContractFactory('ZecreyLegend', {
        libraries: {
            Utils: utilsAddr
        }
    });
    const zecreyLegend = await ZecreyLegend.attach(zecreyLegendAddr)

    const TokenFactory = await ethers.getContractFactory('ZecreyRelatedERC20')
    const LEGToken = await TokenFactory.attach(LEGBEP20Addr)
    const REYToken = await TokenFactory.attach(REYBEP20Addr)

    const sher = namehash.hash('sher.legend');
    var depositBNBTx = await zecreyLegend.depositBNB(sher, {value: ethers.utils.parseEther('0.1')})
    await depositBNBTx.wait()

    // set allowance
    var setAllowanceTx = await LEGToken.approve(zecreyLegend.address, 100000000000)
    await setAllowanceTx.wait()
    setAllowanceTx = await REYToken.approve(zecreyLegend.address, 100000000000)
    await setAllowanceTx.wait()

    var depositBEP20 = await zecreyLegend.depositBEP20(LEGToken.address, '100', sher)
    await depositBEP20.wait()

    depositBEP20 = await zecreyLegend.depositBEP20(REYToken.address, '100', sher)
    await depositBEP20.wait()

    const gavin = namehash.hash('gavin.legend');
    depositBNBTx = await zecreyLegend.depositBNB(gavin, {value: ethers.utils.parseEther('0.1')})
    await depositBNBTx.wait()

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