import chai, { expect } from 'chai';
import hardhat, { ethers } from 'hardhat';
import { smock } from '@defi-wonderland/smock';
import assert from 'assert';

chai.use(smock.matchers);

describe('Desert Mode', function () {
  let owner, acc1, acc2;
  let zkBNB;

  this.beforeEach(async function () {
    [owner, acc1, acc2] = await ethers.getSigners();
    this.mockDesertVerifier = await smock.fake('DesertVerifier');

    const Governance = await ethers.getContractFactory('Governance');
    const governance = await Governance.deploy();
    await governance.deployed();

    const MockZkBNBVerifier = await smock.mock('ZkBNBVerifier');
    const mockZkBNBVerifier = await MockZkBNBVerifier.deploy();
    await mockZkBNBVerifier.deployed();

    const Utils = await ethers.getContractFactory('Utils');
    const utils = await Utils.deploy();
    await utils.deployed();

    const AdditionalZkBNB = await ethers.getContractFactory('AdditionalZkBNB');
    const additionalZkBNB = await AdditionalZkBNB.deploy();
    await additionalZkBNB.deployed();

    const ZkBNBTest = await ethers.getContractFactory('ZkBNBTest', {
      libraries: {
        Utils: utils.address,
      },
    });
    zkBNB = await ZkBNBTest.deploy();
    await zkBNB.deployed();

    const initParams = ethers.utils.defaultAbiCoder.encode(
      ['address', 'address', 'address', 'address', 'bytes32'],
      [
        governance.address,
        mockZkBNBVerifier.address,
        additionalZkBNB.address,
        mockZkBNBVerifier.address,
        ethers.utils.formatBytes32String('genesisStateRoot'),
      ],
    );
    await zkBNB.initialize(initParams);
  });

  it('should be abole to activate desert mode', async () => {
    await expect(await zkBNB.depositBNB(acc1.address, { value: 1000 })).to.emit(zkBNB, 'Deposit');

    // cannot activate desert mode before expired
    await expect(await zkBNB.activateDesertMode()).to.not.to.emit(zkBNB, 'DesertMode');

    await hardhat.network.provider.send('hardhat_mine', ['0x1000000']);
    // able to activate desert mode once expired
    await expect(await zkBNB.activateDesertMode()).to.emit(zkBNB, 'DesertMode');
    assert.equal(await zkBNB.desertMode(), true);
  });

  it('should be able to cancel outstanding deposits', async () => {
    const depositTx = await zkBNB.depositBNB(acc1.address, { value: ethers.utils.parseEther('0.001') });
    const receipt = await depositTx.wait();
    const prEvent = receipt.events.find((ev) => {
      return ev.event === 'NewPriorityRequest';
    });
    const pubdata = prEvent.args[3];

    // activate desert mode first
    await hardhat.network.provider.send('hardhat_mine', ['0x1000000']);
    await expect(await zkBNB.activateDesertMode()).to.emit(zkBNB, 'DesertMode');
    assert.equal(await zkBNB.totalOpenPriorityRequests(), 1);

    // cancel outstanding deposit
    await zkBNB.cancelOutstandingDepositsForDesertMode(5, [pubdata]);
    assert.equal(await zkBNB.totalOpenPriorityRequests(), 0);
  });

  // it.skip('should be able to cancel outstanding NFT deposits', async () => { });
});
