const chai = require('chai');
const { ethers, network } = require('hardhat');
const { smock } = require('@defi-wonderland/smock');
const { deployMockZkBNB } = require('../util');

const { expect } = chai;
chai.use(smock.matchers);

describe('UpgradeableMaster', function () {
  let mockZkBNB;
  let upgradeableMaster;
  let owner, councilMember1, councilMember2, councilMember3;
  let UPGRADE_GATEKEEPER_ROLE;
  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    [owner, councilMember1, councilMember2, councilMember3] = await ethers.getSigners();

    mockZkBNB = await deployMockZkBNB();
    await mockZkBNB.deployed();

    const UpgradeableMaster = await ethers.getContractFactory('UpgradeableMaster');

    upgradeableMaster = await UpgradeableMaster.deploy(
      [councilMember1.address, councilMember2.address, councilMember3.address],
      mockZkBNB.address,
    );
    await upgradeableMaster.deployed();
    UPGRADE_GATEKEEPER_ROLE = await upgradeableMaster.UPGRADE_GATEKEEPER_ROLE();
    upgradeableMaster.grantRole(UPGRADE_GATEKEEPER_ROLE, owner.address);
  });

  context('Access control', () => {
    it('Only owner can grant role', async () => {
      await expect(upgradeableMaster.grantRole(UPGRADE_GATEKEEPER_ROLE, councilMember2.address))
        .to.emit(upgradeableMaster, 'RoleGranted')
        .withArgs(UPGRADE_GATEKEEPER_ROLE, councilMember2.address, owner.address);
      await expect(upgradeableMaster.connect(councilMember1).grantRole(UPGRADE_GATEKEEPER_ROLE, councilMember2.address))
        .to.be.reverted;
    });
    it('Only owner can revoke role', async () => {
      await expect(upgradeableMaster.revokeRole(UPGRADE_GATEKEEPER_ROLE, owner.address))
        .to.emit(upgradeableMaster, 'RoleRevoked')
        .withArgs(UPGRADE_GATEKEEPER_ROLE, owner.address, owner.address);
      await expect(
        upgradeableMaster.connect(councilMember1).revokeRole(UPGRADE_GATEKEEPER_ROLE, councilMember2.address),
      ).to.be.reverted;
    });
    it('Only upgrade gatekeeper can invoke upgrade functions', async () => {
      await expect(upgradeableMaster.connect(councilMember1).upgradeNoticePeriodStarted()).to.be.reverted;
      await expect(upgradeableMaster.connect(councilMember1).upgradePreparationStarted()).to.be.reverted;
      await expect(upgradeableMaster.connect(councilMember1).upgradeCanceled()).to.be.reverted;
      await expect(upgradeableMaster.connect(councilMember1).upgradeFinishes()).to.be.reverted;
    });
    it('Only admin can invoke `changeSecurityCouncilMembers`', async () => {
      const accounts = await ethers.getSigners();
      const newMembers = [accounts[4].address, accounts[5].address, accounts[6].address];
      await expect(upgradeableMaster.connect(councilMember1).changeSecurityCouncilMembers(newMembers)).to.be.reverted;
      await expect(upgradeableMaster.changeSecurityCouncilMembers(newMembers))
        .to.emit(upgradeableMaster, 'SecurityCouncilChanged')
        .withArgs(newMembers);
    });
    it('Only admin can invoke `changeZkBNBAddress`', async () => {
      await expect(upgradeableMaster.connect(councilMember1).changeZkBNBAddress(councilMember2)).to.be.reverted;
      await expect(upgradeableMaster.changeZkBNBAddress(councilMember2.address))
        .to.emit(upgradeableMaster, 'ZkBNBChanged')
        .withArgs(councilMember2.address);
    });
  });
  context('Notice period', () => {
    it('Default notice period should be the shortest', async () => {
      const period = await upgradeableMaster.getNoticePeriod();
      expect(period).to.equal(0);
    });

    it('Preparation status should be activated 4 weeks after notification started', async () => {
      await upgradeableMaster.upgradeNoticePeriodStarted();
      await expect(upgradeableMaster.upgradePreparationStarted()).to.be.reverted;

      const fourWeeks = 4 * 7 * 24 * 60 * 60;

      await network.provider.send('evm_increaseTime', [fourWeeks]);
      await network.provider.send('evm_mine');

      await expect(upgradeableMaster.upgradePreparationStarted()).not.to.be.reverted;
    });

    it('Notice period can be cut by council members', async () => {
      await upgradeableMaster.upgradeNoticePeriodStarted();

      const startTimestamp = await upgradeableMaster.upgradeStartTimestamp();
      await expect(upgradeableMaster.connect(councilMember1).cutUpgradeNoticePeriod('1')).to.be.reverted;

      await expect(upgradeableMaster.upgradePreparationStarted()).to.be.reverted;

      await upgradeableMaster.connect(councilMember1).cutUpgradeNoticePeriod(startTimestamp);
      await upgradeableMaster.connect(councilMember2).cutUpgradeNoticePeriod(startTimestamp);

      await expect(upgradeableMaster.upgradePreparationStarted()).to.be.reverted;

      await upgradeableMaster.connect(councilMember3).cutUpgradeNoticePeriod(startTimestamp);

      await expect(upgradeableMaster.upgradePreparationStarted()).not.to.be.reverted;
    });

    it('Ready for upgrade', async () => {
      let res = await upgradeableMaster.isReadyForUpgrade();
      expect(res).to.be.true;

      await mockZkBNB.setVariable('desertMode', true);

      res = await upgradeableMaster.isReadyForUpgrade();
      expect(res).to.be.false;
    });

    context('Clear upgrade status', () => {
      it('Clear upgrade status when cancelled', async () => {
        await upgradeableMaster.upgradeNoticePeriodStarted();
        const fourWeeks = 4 * 7 * 24 * 60 * 60;

        await expect(upgradeableMaster.upgradeCanceled())
          .to.emit(upgradeableMaster, 'NoticePeriodChange')
          .withArgs(fourWeeks);
      });

      it('Clear upgrade status when finishes', async () => {
        await upgradeableMaster.upgradeNoticePeriodStarted();
        const fourWeeks = 4 * 7 * 24 * 60 * 60;

        await expect(upgradeableMaster.upgradeFinishes())
          .to.emit(upgradeableMaster, 'NoticePeriodChange')
          .withArgs(fourWeeks);
      });
    });
  });
});
