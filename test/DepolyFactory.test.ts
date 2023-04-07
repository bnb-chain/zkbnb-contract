import chai, { expect } from 'chai';
import { ethers } from 'hardhat';
import { smock } from '@defi-wonderland/smock';

/* eslint-disable */
const namehash = require('eth-ens-namehash');

chai.use(smock.matchers);

describe('DeployFactory', function () {
  let DeployFactory;
  let utils;
  let mockGovernanceTarget;
  let mockVerifierTarget;
  let mockZkbnbTarget;
  let mockValidator;
  let mockGovernor;
  let mockListingToken;
  let mockDesertVerifier;
  let mockUpgradeableMaster;
  let owner, addr1, addr2, addr3, addr4;

  const genesisAccountRoot = namehash.hash('genesisAccountRoot');
  const listingFee = ethers.utils.parseEther('100');
  const listingCap = 2 ** 16 - 1;

  let deployAddressParams;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

    const Utils = await ethers.getContractFactory('Utils');
    utils = await Utils.deploy();
    await utils.deployed();

    DeployFactory = await ethers.getContractFactory('DeployFactory');

    mockGovernanceTarget = await smock.fake('Governance');
    mockVerifierTarget = await smock.fake('ZkBNBVerifier');
    const ZkBNB = await ethers.getContractFactory('ZkBNB', {
      libraries: {
        Utils: utils.address,
      },
    });
    mockZkbnbTarget = await smock.fake(ZkBNB);

    mockValidator = addr1;
    mockGovernor = addr2;
    mockListingToken = await smock.fake('ERC20');
    mockDesertVerifier = await smock.fake('DesertVerifier');
    mockUpgradeableMaster = await smock.fake('UpgradeableMaster');

    deployAddressParams = [
      mockGovernanceTarget.address,
      mockVerifierTarget.address,
      mockZkbnbTarget.address,
      mockValidator.address,
      mockGovernor.address,
      mockListingToken.address,
      mockDesertVerifier.address,
      mockUpgradeableMaster.address,
    ];
  });

  describe('deploy stuffs', () => {
    let deployFactory;
    let event;
    let deployedContracts;
    beforeEach(async () => {
      deployFactory = await DeployFactory.deploy(deployAddressParams, genesisAccountRoot, listingFee, listingCap);
      await deployFactory.deployed();
      const deployFactoryTx = await deployFactory.deployTransaction;
      const receipt = await deployFactoryTx.wait();
      event = receipt.events?.filter(({ event }) => {
        return event == 'Addresses';
      });
      deployedContracts = event[0].args;
    });

    it('should proxy for target contract', async function () {
      expect(event).to.be.length(1);

      const { governance, verifier, zkbnb } = deployedContracts;
      const Proxy = await ethers.getContractFactory('Proxy');

      await isProxyTarget(governance, mockGovernanceTarget.address);
      await isProxyTarget(verifier, mockVerifierTarget.address);
      await isProxyTarget(zkbnb, mockZkbnbTarget.address);

      async function isProxyTarget(proxy, target) {
        const proxyContract = Proxy.attach(proxy);
        const proxyTarget = await proxyContract.getTarget();
        expect(proxyTarget).to.be.equal(target);
      }
    });

    it('should set masterContract into the upgradeable gatekeeper', async () => {
      const { gatekeeper } = deployedContracts;
      const UpgradeGatekeeper = await ethers.getContractFactory('UpgradeGatekeeper');

      const upgradeGatekeeper = UpgradeGatekeeper.attach(gatekeeper);
      const master = await upgradeGatekeeper.masterContract();
      expect(master).to.be.equal(mockUpgradeableMaster.address);
    });

    it('should set upgradeable contract into the upgradeable gatekeeper', async () => {
      const { governance, verifier, zkbnb, gatekeeper } = deployedContracts;
      const UpgradeGatekeeper = await ethers.getContractFactory('UpgradeGatekeeper');

      const upgradeGatekeeper = UpgradeGatekeeper.attach(gatekeeper);
      const governanceProxy = await upgradeGatekeeper.managedContracts(0);
      const verifierProxy = await upgradeGatekeeper.managedContracts(1);
      const zkbnbProxy = await upgradeGatekeeper.managedContracts(2);

      expect(governanceProxy).to.be.equal(governance);
      expect(verifierProxy).to.be.equal(verifier);
      expect(zkbnbProxy).to.be.equal(zkbnb);
    });
  });
});
