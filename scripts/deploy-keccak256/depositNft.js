const hardhat = require('hardhat');
const namehash = require('eth-ens-namehash');
const { getDeployedAddresses, getZkBNBProxy } = require('./utils');
const { ethers } = hardhat;

async function main() {
  const addrs = getDeployedAddresses(hardhat.network.name, 'info/addresses.json');
  const zkbnb = await getZkBNBProxy(addrs.zkbnbProxy);

  // tokens
  const ERC721Factory = await ethers.getContractFactory('ZkBNBRelatedERC721');
  const ERC721 = await ERC721Factory.attach(addrs.ERC721);

  // deposit bnb
  console.log('Approve Nft...');
  // set allowance
  const approveTx = await ERC721.approve(zkbnb.address, '0');
  await approveTx.wait();
  // deposit nft
  console.log('Deposit Nft...');
  const depositERC721Tx = await zkbnb.depositNft('sher', addrs.ERC721, '0');
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
