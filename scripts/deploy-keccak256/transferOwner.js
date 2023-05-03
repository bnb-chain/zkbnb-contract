/*
 * @Description transferOwner
 * @Author: rain.z
 * @Date: 2023/4/20 10:11
 */

const { getDeployedAddresses } = require('./utils');
const hardhat = require('hardhat');
const { Wallet } = require('ethers');
const { ethers } = hardhat;

async function main() {
  const gnosisOwner = process.env.OWNER;

  if (!gnosisOwner) {
    return;
  }

  const addrs = getDeployedAddresses('info/addresses.json');
  const { DefaultNftFactory, governance, utils } = addrs;

  const zkBNBNftFactory = await ethers.getContractFactory('ZkBNBNFTFactory');
  const defaultFactoryContract = zkBNBNftFactory.attach(DefaultNftFactory);

  // DefaultNFTFactory
  const transferOwnershipTx = await defaultFactoryContract.transferOwnership(gnosisOwner, {
    gasLimit: 6721975,
  });
  await transferOwnershipTx.wait();

  // Governance
  const governanceFactory = await ethers.getContractFactory('Governance', {
    libraries: {
      Utils: utils,
    },
  });
  const governanceContract = governanceFactory.attach(governance);
  await governanceContract.changeGovernor(gnosisOwner, {
    gasLimit: 6721975,
  });

  // proxy
  // const governanceProxy = await (await ethers.getContractFactory('Proxy')).attach(addrs.governance);
  // const verifierProxy = await (await ethers.getContractFactory('Proxy')).attach(addrs.verifierProxy);
  // const zkbnbProxy = await (await ethers.getContractFactory('Proxy')).attach(addrs.zkbnbProxy);
  //
  // await governanceProxy.transferMastership(gnosisOwner, {
  //   gasLimit: 6721975,
  // });
  // await verifierProxy.transferMastership(gnosisOwner, {
  //   gasLimit: 6721975,
  // });
  // await zkbnbProxy.transferMastership(gnosisOwner, {
  //   gasLimit: 6721975,
  // });
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err.message || err);
    process.exit(1);
  });
