const hardhat = require('hardhat');
const { getDeployedAddresses, getZkBNBProxy } = require('./utils');
const { ethers } = hardhat;

async function main() {
  const addrs = getDeployedAddresses('info/addresses.json');
  const [owner] = await ethers.getSigners();

  const zkbnb = await getZkBNBProxy(addrs.zkbnbProxy);
  console.log('Register account for treasury, gas...');
  const validators = (process.env.VALIDATORS || owner.address).split(',');
  const treasuryAccountAddress = process.env.TREASURY_ACCOUNT_ADDRESS || validators[0] || owner.address;
  const gasAccountAddress = process.env.GAS_ACCOUNT_ADDRESS || validators[1] || owner.address;
  if (treasuryAccountAddress.toLocaleLowerCase() === gasAccountAddress.toLocaleLowerCase()) {
    throw new Error('Treasury and Gas account Addresses cannot be the same');
  }
  console.log(`Treasury account address: ${treasuryAccountAddress}`);
  console.log(`Gas account address: ${gasAccountAddress}`);
  let registerAccount = await zkbnb.depositBNB(treasuryAccountAddress, {
    value: ethers.utils.parseEther('0.01'),
  });
  await registerAccount.wait();
  registerAccount = await zkbnb.depositBNB(gasAccountAddress, {
    value: ethers.utils.parseEther('0.01'),
  });
  await registerAccount.wait();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err.message || err);
    process.exit(1);
  });
