const hardhat = require('hardhat');
const namehash = require('eth-ens-namehash');
const { getDeployedAddresses, getZkBNBProxy } = require('./utils');
const { ethers } = hardhat;

async function main() {
  const addrs = getDeployedAddresses('info/addresses.json');
  const zkbnb = await getZkBNBProxy(addrs.zkbnbProxy);

  console.log('FullExit NFT...');
  // full exit
  const fullExitNftTx = await zkbnb.requestFullExitNft('sher', '0');
  await fullExitNftTx.wait();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err.message || err);
    process.exit(1);
  });
