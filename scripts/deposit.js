const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')

const zecreyLegendAddr = '0x9bFE5149E86Cd8A47DddB82b7800813d5A3adab6'
const utilsAddr = '0x0D3014961da0f9603Dee59B63c703eA6202AD480'

async function main() {
    // zecrey legend
    const ZecreyLegend = await ethers.getContractFactory('ZecreyLegend', {
        libraries: {
            Utils: utilsAddr
        }
    });
    const zecreyLegend = await ZecreyLegend.attach(zecreyLegendAddr)

    const sher = namehash.hash('sher.legend');
    var depositBNBTx = await zecreyLegend.depositBNB(sher, {value: ethers.utils.parseEther('0.01')})
    await depositBNBTx.wait()

    const gavin = namehash.hash('gavin.legend');
    depositBNBTx = await zecreyLegend.depositBNB(gavin, {value: ethers.utils.parseEther('0.01')})
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