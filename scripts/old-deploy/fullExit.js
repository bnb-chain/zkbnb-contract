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

    const gavin = namehash.hash('gavin.legend');
    var fullExitTx = await zecreyLegend.requestFullExit(gavin, '0x0000000000000000000000000000000000000000')
    await fullExitTx.wait()

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