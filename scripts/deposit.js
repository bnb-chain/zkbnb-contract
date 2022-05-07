const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')

async function main() {
    // zecrey legend
    const ZecreyLegend = await ethers.getContractFactory('ZecreyLegend', {
        libraries: {
            Utils: '0xa32b47E2D8634b611660238f66E6fD2148d093CE'
        }
    });
    const zecreyLegend = await ZecreyLegend.attach('0x53152a8f7C18FD7530f046E7D4Cee4D579743922')

    const hashVal = namehash.hash('sher.legend');
    const depositBNBTx = await zecreyLegend.depositBNB(hashVal, {value: ethers.utils.parseEther('0.01')})
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