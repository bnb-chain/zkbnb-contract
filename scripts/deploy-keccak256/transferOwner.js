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
  const { DefaultNftFactory, governance } = addrs;

  // const [owner] = await ethers.getSigners();

  const contractFactories = await getContractFactories();
  const defaultFactoryContract = contractFactories.DefaultNftFactory.attach(DefaultNftFactory);

  // DefaultNFTFactory
  const transferOwnershipTx = await defaultFactoryContract.transferOwnership(gnosisOwner, {
    gasLimit: 6721975,
  });
  await transferOwnershipTx.wait();

  // Governance
  const governanceContract = contractFactories.Governance.attach(governance);
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

async function getContractFactories() {
  const Utils = await ethers.getContractFactory('Utils');
  const utils = await Utils.deploy();
  await utils.deployed();

  return {
    TokenFactory: await ethers.getContractFactory('ZkBNBRelatedERC20'),
    ERC721Factory: await ethers.getContractFactory('ZkBNBRelatedERC721'),
    Governance: await ethers.getContractFactory('Governance', {
      libraries: {
        Utils: utils.address,
      },
    }),
    AssetGovernance: await ethers.getContractFactory('AssetGovernance'),
    Verifier: await ethers.getContractFactory('ZkBNBVerifier'),
    ZkBNB: await ethers.getContractFactory('ZkBNB', {
      libraries: {
        Utils: utils.address,
      },
    }),
    DeployFactory: await ethers.getContractFactory('DeployFactory'),
    DefaultNftFactory: await ethers.getContractFactory('ZkBNBNFTFactory'),
    UpgradeableMaster: await ethers.getContractFactory('UpgradeableMaster'),
    Utils: utils,
  };
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Error:', err.message || err);
    process.exit(1);
  });
