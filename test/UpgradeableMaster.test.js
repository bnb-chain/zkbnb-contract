const chai = require('chai');
const { ethers, network } = require('hardhat');
const { smock } = require('@defi-wonderland/smock');

const { expect } = chai;
chai.use(smock.matchers);

describe('UpgradeableMaster', function () {
  let mockZkBNB;
  let upgradeableMaster;
  let owner, councilMember1, councilMember2, councilMember3;
  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    [owner, councilMember1, councilMember2, councilMember3] =
      await ethers.getSigners();

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

    const UpgradeableMaster = await ethers.getContractFactory(
      'UpgradeableMaster',
    );

    upgradeableMaster = await UpgradeableMaster.deploy(
      [councilMember1.address, councilMember2.address, councilMember3.address],
      mockZkBNB.address,
    );
    await upgradeableMaster.deployed();
  });

  context('Notice period', () => {
    it('Default notice period should be the shortest', async () => {
      const period = await upgradeableMaster.getNoticePeriod();
      expect(period).to.equal(0);
    });

    it('Preparation status should be activated 4 weeks after notification started', async () => {
      await upgradeableMaster.upgradeNoticePeriodStarted();
      await expect(upgradeableMaster.upgradePreparationStarted()).to.be
        .reverted;

      const fourWeeks = 4 * 7 * 24 * 60 * 60;

      await network.provider.send('evm_increaseTime', [fourWeeks]);
      await network.provider.send('evm_mine');

      await expect(upgradeableMaster.upgradePreparationStarted()).not.to.be
        .reverted;
    });

    it('Notice period can be cut by council members', async () => {
      await upgradeableMaster.upgradeNoticePeriodStarted();

      await expect(upgradeableMaster.upgradePreparationStarted()).to.be
        .reverted;

      await upgradeableMaster.connect(councilMember1).cutUpgradeNoticePeriod();
      await upgradeableMaster.connect(councilMember2).cutUpgradeNoticePeriod();

      await expect(upgradeableMaster.upgradePreparationStarted()).to.be
        .reverted;

      await upgradeableMaster.connect(councilMember3).cutUpgradeNoticePeriod();

      await expect(upgradeableMaster.upgradePreparationStarted()).not.to.be
        .reverted;
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

    // TODO: add access control to `UpgradeableMaster` contract
    context.skip('Access control', () => {
      it('Only council member can invoke `upgradeNoticePeriodStarted`', async () => {
        await upgradeableMaster.setOperator(councilMember1.address);

        await expect(upgradeableMaster.upgradeNoticePeriodStarted()).to.be
          .reverted;
        await expect(
          upgradeableMaster
            .connect(councilMember1)
            .upgradeNoticePeriodStarted(),
        ).not.to.be.reverted;
      });
    });
  });
});
