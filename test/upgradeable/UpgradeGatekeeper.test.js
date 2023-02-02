const chai = require('chai');
const { ethers } = require('hardhat');
const { smock } = require('@defi-wonderland/smock');

const { expect } = chai;
chai.use(smock.matchers);

describe('UpgradeGatekeeper', function () {
  let mockGovernance;
  let mockZkBNBVerifier;
  let mockZNSController;
  let mockPublicResolver;
  let mockZkBNB;
  let mockZkBNBNew;
  let newTargets;

  let proxyMockGovernance;
  let proxyMockZkBNBVerifier;
  let proxyMockZNSController;
  let proxyMockPublicResolver;
  let proxyMockZkBNB;

  let mockUpgradeableMaster;
  let upgradeGatekeeper;

  // `ZkBNB` needs to link to library `Utils` before deployed
  let utils;
  let owner, addr1, addr2;

  before(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // 1. deploy logic contracts
    const MockGovernance = await smock.mock('Governance');
    mockGovernance = await MockGovernance.deploy();
    await mockGovernance.deployed();

    const MockZkBNBVerifier = await smock.mock('ZkBNBVerifier');
    mockZkBNBVerifier = await MockZkBNBVerifier.deploy();
    await mockZkBNBVerifier.deployed();

    const MockZNSController = await smock.mock('ZNSController');
    mockZNSController = await MockZNSController.deploy();
    await mockZNSController.deployed();

    const MockPublicResolver = await smock.mock('PublicResolver');
    mockPublicResolver = await MockPublicResolver.deploy();
    await mockPublicResolver.deployed();

    const Utils = await ethers.getContractFactory('Utils');
    utils = await Utils.deploy();
    await utils.deployed();
    const MockZkBNB = await smock.mock('ZkBNB', {
      libraries: {
        Utils: utils.address,
      },
    });
    mockZkBNB = await MockZkBNB.deploy();
    await mockZkBNB.deployed();
    mockZkBNBNew = await MockZkBNB.deploy();
    await mockZkBNBNew.deployed();
    newTargets = [
      ethers.constants.AddressZero,
      ethers.constants.AddressZero,
      ethers.constants.AddressZero,
      ethers.constants.AddressZero,
      mockZkBNBNew.address,
    ];

    // 2. deploy proxy contracts
    const MockProxy = await smock.mock('Proxy');

    mockGovernance.initialize.returns();
    mockZkBNBVerifier.initialize.returns();
    mockZNSController.initialize.returns();
    mockPublicResolver.initialize.returns();
    mockZkBNB.initialize.returns();

    proxyMockGovernance = await MockProxy.deploy(mockGovernance.address, owner.address);
    proxyMockZkBNBVerifier = await MockProxy.deploy(mockZkBNBVerifier.address, owner.address);
    proxyMockZNSController = await MockProxy.deploy(mockZNSController.address, owner.address);
    proxyMockPublicResolver = await MockProxy.deploy(mockPublicResolver.address, owner.address);
    proxyMockZkBNB = await MockProxy.deploy(mockZkBNB.address, owner.address);
    await proxyMockGovernance.deployed();
    await proxyMockZkBNBVerifier.deployed();
    await proxyMockZNSController.deployed();
    await proxyMockPublicResolver.deployed();
    await proxyMockZkBNB.deployed();

    // 3. deploy UpgradeableMaster
    const MockUppgradeableMaster = await smock.mock('UpgradeableMaster');
    mockUpgradeableMaster = await MockUppgradeableMaster.deploy(
      [addr1.address, addr1.address, addr1.address],
      mockZkBNB.address,
    );
    await mockUpgradeableMaster.deployed();

    // 4. deploy UpgradeGatekeeper
    const UpgradeGatekeeper = await ethers.getContractFactory('UpgradeGatekeeper');
    upgradeGatekeeper = await UpgradeGatekeeper.deploy(mockUpgradeableMaster.address);
    await upgradeGatekeeper.deployed();

    const UPGRADE_GATEKEEPER_ROLE = await mockUpgradeableMaster.UPGRADE_GATEKEEPER_ROLE();
    mockUpgradeableMaster.grantRole(UPGRADE_GATEKEEPER_ROLE, upgradeGatekeeper.address);

    expect(await upgradeGatekeeper.masterContract()).to.equal(mockUpgradeableMaster.address);

    // check length of `managedContracts` array which is stored at storage slot 0
    const initialLength = ethers.BigNumber.from(await ethers.provider.getStorageAt(upgradeGatekeeper.address, 0));
    expect(initialLength.eq(0)).to.equal(true);
  });

  describe('Add new upgradeable contracts', function () {
    it('added `proxyGovernance`', async function () {
      await expect(upgradeGatekeeper.addUpgradeable(proxyMockGovernance.address)).not.to.be.reverted;

      expect(ethers.BigNumber.from(await ethers.provider.getStorageAt(upgradeGatekeeper.address, 0)).eq(1)).to.equal(
        true,
      );

      expect(await upgradeGatekeeper.managedContracts(0)).to.equal(proxyMockGovernance.address);
    });

    it('added `proxyZkBNBVerifier`', async function () {
      await expect(upgradeGatekeeper.addUpgradeable(proxyMockZkBNBVerifier.address)).not.to.be.reverted;

      expect(ethers.BigNumber.from(await ethers.provider.getStorageAt(upgradeGatekeeper.address, 0)).eq(2)).to.equal(
        true,
      );

      expect(await upgradeGatekeeper.managedContracts(1)).to.equal(proxyMockZkBNBVerifier.address);
    });

    it('added `proxyZNSController`', async function () {
      await expect(upgradeGatekeeper.addUpgradeable(proxyMockZNSController.address)).not.to.be.reverted;

      expect(ethers.BigNumber.from(await ethers.provider.getStorageAt(upgradeGatekeeper.address, 0)).eq(3)).to.equal(
        true,
      );

      expect(await upgradeGatekeeper.managedContracts(2)).to.equal(proxyMockZNSController.address);
    });

    it('added `proxyPublicResolver`', async function () {
      await expect(upgradeGatekeeper.addUpgradeable(proxyMockPublicResolver.address)).not.to.be.reverted;

      expect(ethers.BigNumber.from(await ethers.provider.getStorageAt(upgradeGatekeeper.address, 0)).eq(4)).to.equal(
        true,
      );

      expect(await upgradeGatekeeper.managedContracts(3)).to.equal(proxyMockPublicResolver.address);
    });

    it('added `proxyZkBNB`', async function () {
      await expect(upgradeGatekeeper.addUpgradeable(proxyMockZkBNB.address)).not.to.be.reverted;

      expect(ethers.BigNumber.from(await ethers.provider.getStorageAt(upgradeGatekeeper.address, 0)).eq(5)).to.equal(
        true,
      );

      expect(await upgradeGatekeeper.managedContracts(4)).to.equal(proxyMockZkBNB.address);
    });
  });

  describe('Check normal upgrade', function () {
    it('start upgrade', async function () {
      // verisonId == 0, noticePeriod == 0
      await expect(upgradeGatekeeper.startUpgrade(newTargets))
        .to.emit(upgradeGatekeeper, 'NoticePeriodStart')
        .withArgs(0, newTargets, 0);

      // upgradeStatus.NoticePeriod == 1
      expect(await upgradeGatekeeper.upgradeStatus()).to.equal(1);
    });

    it('start preparation', async function () {
      mockUpgradeableMaster.upgradePreparationStarted.returns();

      // verisonId == 0
      await expect(upgradeGatekeeper.startPreparation()).to.emit(upgradeGatekeeper, 'PreparationStart').withArgs(0);

      // upgradeStatus.NoticePeriod == 2
      expect(await upgradeGatekeeper.upgradeStatus()).to.equal(2);
    });

    it('finish upgrade', async function () {
      mockUpgradeableMaster.upgradeFinishes.returns();
      proxyMockZkBNB.upgradeTarget.returns();

      const mockParamters = ['0x3a', '0x44', '0x3d', '0x83', '0x81'];
      await expect(upgradeGatekeeper.finishUpgrade(mockParamters))
        .to.emit(upgradeGatekeeper, 'UpgradeComplete')
        .withArgs(1, newTargets);

      // Check states are cleared
      // versionId == 1
      expect(await upgradeGatekeeper.versionId()).to.equal(1);

      // upgradeStatus.NoticePeriod == 0
      expect(await upgradeGatekeeper.upgradeStatus()).to.equal(0);

      // upgradeStatus.NoticePeriod == 0
      expect(await upgradeGatekeeper.noticePeriodFinishTimestamp()).to.equal(0);

      // nextTargets.length == 0
      expect(ethers.BigNumber.from(await ethers.provider.getStorageAt(upgradeGatekeeper.address, 3)).eq(0)).to.equal(
        true,
      );
    });
  });

  describe('Check upgrade cancellation', function () {
    it('should fail to cancel before upgrade', async function () {
      await expect(upgradeGatekeeper.cancelUpgrade()).to.be.revertedWith('cpu11');
    });

    it('cancel after start upgrade', async function () {
      await upgradeGatekeeper.startUpgrade(newTargets);
      mockUpgradeableMaster.upgradeCanceled.returns();

      // verisonId == 1
      await expect(upgradeGatekeeper.cancelUpgrade()).to.emit(upgradeGatekeeper, 'UpgradeCancel').withArgs(1);

      // upgradeStatus.NoticePeriod == 0
      expect(await upgradeGatekeeper.upgradeStatus()).to.equal(0);

      // upgradeStatus.NoticePeriod == 0
      expect(await upgradeGatekeeper.noticePeriodFinishTimestamp()).to.equal(0);

      // nextTargets.length == 0
      expect(ethers.BigNumber.from(await ethers.provider.getStorageAt(upgradeGatekeeper.address, 3)).eq(0)).to.equal(
        true,
      );
    });

    it('cancel after start preparation', async function () {
      mockUpgradeableMaster.upgradePreparationStarted.returns();

      await upgradeGatekeeper.startUpgrade(newTargets);
      await upgradeGatekeeper.startPreparation();

      // verisonId == 1
      await expect(upgradeGatekeeper.cancelUpgrade()).to.emit(upgradeGatekeeper, 'UpgradeCancel').withArgs(1);
      // upgradeStatus.NoticePeriod == 0
      expect(await upgradeGatekeeper.upgradeStatus()).to.equal(0);

      // upgradeStatus.NoticePeriod == 0
      expect(await upgradeGatekeeper.noticePeriodFinishTimestamp()).to.equal(0);

      // nextTargets.length == 0
      expect(ethers.BigNumber.from(await ethers.provider.getStorageAt(upgradeGatekeeper.address, 3)).eq(0)).to.equal(
        true,
      );
    });

    it('should fail to cancel after finish upgrade', async function () {
      mockUpgradeableMaster.upgradePreparationStarted.returns();

      await upgradeGatekeeper.startUpgrade(newTargets);
      await upgradeGatekeeper.startPreparation();
      mockUpgradeableMaster.upgradeFinishes.returns();
      proxyMockZkBNB.upgradeTarget.returns();

      const mockParamters = ['0x3a', '0x44', '0x3d', '0x83', '0x81'];
      await upgradeGatekeeper.finishUpgrade(mockParamters);
      await expect(upgradeGatekeeper.cancelUpgrade()).to.be.revertedWith('cpu11');
    });
  });
});
