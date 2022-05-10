const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')

const zecreyLegendAddr = '0xD27624F18D423b990A7859A3d72916A3DD783EEE'
const utilsAddr = '0x01f7Ce1045B1B50Edd5CC117272B6059dDe8c29c'

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