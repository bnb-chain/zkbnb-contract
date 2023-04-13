const hardhat = require('hardhat');
const { getDeployedAddresses } = require('../deploy-keccak256/utils');

const { ethers } = hardhat;

async function getUpgradeableContractImplement() {
  const addrs = getDeployedAddresses('info/addresses.json');
  const contractFactories = await getContractFactories();

  /* ----------------------- current implement contracts ---------------------- */
  const governanceProxy = await contractFactories.Proxy.attach(addrs.governance);
  const verifierProxy = await contractFactories.Proxy.attach(addrs.verifierProxy);
  const zkbnbProxy = await contractFactories.Proxy.attach(addrs.zkbnbProxy);

  const governance = await governanceProxy.getTarget();
  const verifier = await verifierProxy.getTarget();
  const zkbnb = await zkbnbProxy.getTarget();

  return {
    governance,
    verifier,
    zkbnb,
  };
}

async function getContractFactories() {
  const Utils = await ethers.getContractFactory('Utils');
  const utils = await Utils.deploy();
  await utils.deployed();

  return {
    TokenFactory: await ethers.getContractFactory('ZkBNBRelatedERC20'),
    ERC721Factory: await ethers.getContractFactory('ZkBNBRelatedERC721'),
    Governance: await ethers.getContractFactory('Governance'),
    AssetGovernance: await ethers.getContractFactory('AssetGovernance'),
    Verifier: await ethers.getContractFactory('ZkBNBVerifier'),
    ZkBNB: await ethers.getContractFactory('ZkBNB', {
      libraries: {
        Utils: utils.address,
      },
    }),
    DeployFactory: await ethers.getContractFactory('DeployFactory', {
      libraries: {
        Utils: utils.address,
      },
    }),
    DefaultNftFactory: await ethers.getContractFactory('ZkBNBNFTFactory'),
    UpgradeableMaster: await ethers.getContractFactory('UpgradeableMaster'),
    UpgradeGatekeeper: await ethers.getContractFactory('UpgradeGatekeeper'),
    Proxy: await ethers.getContractFactory('Proxy'),
  };
}
module.exports = {
  getContractFactories,
  getUpgradeableContractImplement,
};
