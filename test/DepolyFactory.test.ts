import chai, { expect } from 'chai';
import { ethers } from 'hardhat';
import { FakeContract, smock } from '@defi-wonderland/smock';

/* eslint-disable */
const namehash = require('eth-ens-namehash');

chai.use(smock.matchers);

describe('DeployFactory', function () {
  let DeployFactory;
  let utils;
  let mockGovernanceTarget;
  let mockVerifierTarget;
  let mockZkbnbTarget;
  let mockZnsControllerTarget;
  let mockZnsResolverTarget;
  let mockValidator;
  let mockGovernor;
  let mockListingToken;
  let mockZns;
  let mockPriceOracle;
  let mockUpgradeableMaster;
  let owner, addr1, addr2, addr3, addr4;

  const baseNode = namehash.hash('legend');
  const genesisAccountRoot = namehash.hash('genesisAccountRoot');
  const listingFee = ethers.utils.parseEther('100');
  const listingCap = 2 ** 16 - 1;

  let deployAddressParams;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

    const Utils = await ethers.getContractFactory('Utils');
    utils = await Utils.deploy();
    await utils.deployed();

    DeployFactory = await ethers.getContractFactory('DeployFactory', {
      libraries: {
        Utils: utils.address,
      },
    });

    mockGovernanceTarget = await smock.fake('Governance');
    mockVerifierTarget = await smock.fake('ZkBNBVerifier');
    const ZkBNB = await ethers.getContractFactory('ZkBNB');
    mockZkbnbTarget = await smock.fake(ZkBNB);

    mockZnsControllerTarget = await smock.fake('ZNSController');
    mockZnsResolverTarget = await smock.fake('PublicResolver');
    mockValidator = addr1;
    mockGovernor = addr2;
    mockListingToken = await smock.fake('ERC20');
    mockZns = await smock.fake('ZNSRegistry');
    mockPriceOracle = await smock.fake('StablePriceOracle');
    mockUpgradeableMaster = await smock.fake('UpgradeableMaster');

    deployAddressParams = [
      mockGovernanceTarget.address,
      mockVerifierTarget.address,
      mockZkbnbTarget.address,
      mockZnsControllerTarget.address,
      mockZnsResolverTarget.address,
      mockValidator.address,
      mockGovernor.address,
      mockListingToken.address,
      mockZns.address,
      mockPriceOracle.address,
      mockUpgradeableMaster.address,
    ];
  });

  it('should self destruct', async function () {
    const deployFactory = await DeployFactory.deploy(
      deployAddressParams,
      genesisAccountRoot,
      listingFee,
      listingCap,
      baseNode,
    );

    const TestHelper = await ethers.getContractFactory('TestHelper');
    const testHelper = await TestHelper.deploy();
    const result = await testHelper.contractExists(deployFactory.address);
    expect(result).to.be.equal(false);
  });
  describe('deploy stuffs', () => {
    let deployFactory;
    let event;
    let deployedContracts;
    beforeEach(async () => {
      deployFactory = await DeployFactory.deploy(
        deployAddressParams,
        genesisAccountRoot,
        listingFee,
        listingCap,
        baseNode,
      );
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

      const { governance, assetGovernance, verifier, znsController, znsResolver, zkbnb, gatekeeper } =
        deployedContracts;
      const Proxy = await ethers.getContractFactory('Proxy');

      await isProxyTarget(governance, mockGovernanceTarget.address);
      await isProxyTarget(verifier, mockVerifierTarget.address);
      await isProxyTarget(znsController, mockZnsControllerTarget.address);
      await isProxyTarget(znsResolver, mockZnsResolverTarget.address);
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
      const { governance, assetGovernance, verifier, znsController, znsResolver, zkbnb, gatekeeper } =
        deployedContracts;
      const UpgradeGatekeeper = await ethers.getContractFactory('UpgradeGatekeeper');

      const upgradeGatekeeper = UpgradeGatekeeper.attach(gatekeeper);
      const governanceProxy = await upgradeGatekeeper.managedContracts(0);
      const verifierProxy = await upgradeGatekeeper.managedContracts(1);
      const znsControllerProxy = await upgradeGatekeeper.managedContracts(2);
      const znsResolverProxy = await upgradeGatekeeper.managedContracts(3);
      const zkbnbProxy = await upgradeGatekeeper.managedContracts(4);

      expect(governanceProxy).to.be.equal(governance);
      expect(verifierProxy).to.be.equal(verifier);
      expect(znsControllerProxy).to.be.equal(znsController);
      expect(znsResolverProxy).to.be.equal(znsResolver);
      expect(zkbnbProxy).to.be.equal(zkbnb);
    });
  });
});
