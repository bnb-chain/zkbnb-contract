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
  const znsControllerProxy = await contractFactories.Proxy.attach(addrs.znsControllerProxy);
  const znsResolverProxy = await contractFactories.Proxy.attach(addrs.znsResolverProxy);

  const governance = await governanceProxy.getTarget();
  const verifier = await verifierProxy.getTarget();
  const zkbnb = await zkbnbProxy.getTarget();
  const znsController = await znsControllerProxy.getTarget();
  const znsResolver = await znsResolverProxy.getTarget();

  return {
    governance,
    verifier,
    zkbnb,
    znsController,
    znsResolver,
  };
}

async function getContractFactories() {
  const Utils = await ethers.getContractFactory('Utils');
  const utils = await Utils.deploy();
  await utils.deployed();
  // TODO: remove in next version
  const NftHelperLibrary = await ethers.getContractFactory('NftHelperLibrary');
  const nftHelperLibrary = await NftHelperLibrary.deploy();
  await nftHelperLibrary.deployed();

  return {
    TokenFactory: await ethers.getContractFactory('ZkBNBRelatedERC20'),
    ERC721Factory: await ethers.getContractFactory('ZkBNBRelatedERC721'),
    ZNSRegistry: await ethers.getContractFactory('ZNSRegistry'),
    ZNSResolver: await ethers.getContractFactory('PublicResolver'),
    ZNSPriceOracle: await ethers.getContractFactory('StablePriceOracle'),
    ZNSController: await ethers.getContractFactory('ZNSController'),
    Governance: await ethers.getContractFactory('Governance'),
    AssetGovernance: await ethers.getContractFactory('AssetGovernance'),
    Verifier: await ethers.getContractFactory('ZkBNBVerifier'),
    ZkBNB: await ethers.getContractFactory('ZkBNB', {
      libraries: {
        NftHelperLibrary: nftHelperLibrary.address,
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
