const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')
const {getDeployedAddresses, getZecreyLegendProxy} = require("./utils");

async function main() {
    const addrs = getDeployedAddresses('info/addresses.json')
    const zecreyLegend = await getZecreyLegendProxy(addrs.zecreyLegendProxy)

    // tokens
    const ERC721Factory = await ethers.getContractFactory('ZecreyRelatedERC721')
    const ERC721 = await ERC721Factory.attach(addrs.ERC721)

    // deposit bnb
    console.log('Approve Nft...')
    // set allowance
    let approveTx = await ERC721.approve(zecreyLegend.address, '0');
    await approveTx.wait();
    // deposit nft
    console.log('Deposit Nft...');
    let depositERC721Tx = await zecreyLegend.depositNft('sher', addrs.ERC721, '0');
    await depositERC721Tx.wait();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error('Error:', err.message || err);
        process.exit(1);
    });