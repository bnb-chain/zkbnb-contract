const chai = require('chai');
const { ethers, network } = require('hardhat');
const { smock } = require('@defi-wonderland/smock');

const { expect } = chai;
chai.use(smock.matchers);

describe('UpgradeableMaster', function () {
  let mockStorage;
  let upgradeableMaster;
  let owner, addr1, addr2, addr3;
  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    const MockStorage = await smock.mock('Storage');
    mockStorage = await MockStorage.deploy();
    await mockStorage.deployed();

    const UpgradeableMaster = await ethers.getContractFactory(
      'UpgradeableMaster',
    );

    upgradeableMaster = await UpgradeableMaster.deploy(
      [addr1.address, addr2.address, addr3.address],
      mockStorage.address,
    );
    await upgradeableMaster.deployed();
  });

  context('Notice period', () => {
    it('Default notice period should been shortest', async () => {
      const period = await upgradeableMaster.getNoticePeriod();
      expect(period).to.equal(0);
    });
    it('Notification that upgrade preparation status is activated', async () => {
      await upgradeableMaster.upgradeNoticePeriodStarted();
      await expect(upgradeableMaster.upgradePreparationStarted()).to.be
        .reverted;

      const fourWeeks = 4 * 7 * 24 * 60 * 60;

      await network.provider.send('evm_increaseTime', [fourWeeks]);
      await network.provider.send('evm_mine');

      await expect(upgradeableMaster.upgradePreparationStarted()).not.to.be
        .reverted;
    });
    it('cut upgrade notice period', async () => {
      await upgradeableMaster.upgradeNoticePeriodStarted();

      await expect(upgradeableMaster.upgradePreparationStarted()).to.be
        .reverted;

      await upgradeableMaster.connect(addr1).cutUpgradeNoticePeriod();
      await upgradeableMaster.connect(addr2).cutUpgradeNoticePeriod();

      await expect(upgradeableMaster.upgradePreparationStarted()).to.be
        .reverted;

      await upgradeableMaster.connect(addr3).cutUpgradeNoticePeriod();

      await expect(upgradeableMaster.upgradePreparationStarted()).not.to.be
        .reverted;
    });
    it('Ready for upgrade', async () => {
      let res = await upgradeableMaster.isReadyForUpgrade();
      expect(res).to.be.true;

      await mockStorage.setVariable('desertMode', true);

      res = await upgradeableMaster.isReadyForUpgrade();
      expect(res).to.be.false;
    });
    it('clear Upgrade Status', async () => {
      await upgradeableMaster.upgradeNoticePeriodStarted();
      const fourWeeks = 4 * 7 * 24 * 60 * 60;

      await expect(upgradeableMaster.upgradeCanceled())
        .to.emit(upgradeableMaster, 'NoticePeriodChange')
        .withArgs(fourWeeks);
    });
    it('access control', async () => {
      await upgradeableMaster.setOperator(addr1.address);

      await expect(upgradeableMaster.upgradeNoticePeriodStarted()).to.be
        .reverted;
      await expect(
        upgradeableMaster.connect(addr1).upgradeNoticePeriodStarted(),
      ).not.to.be.reverted;
    });
  });
});
