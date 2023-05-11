const chai = require('chai');
const { ethers } = require('hardhat');
const { smock } = require('@defi-wonderland/smock');
const { PubDataType, encodePubData, PubDataTypeMap, deployZkBNB, deployZkBNBProxy } = require('./util');
const { expect } = chai;
chai.use(smock.matchers);

describe('ZkBNB', function () {
  let mockGovernance;
  let mockZkBNBVerifier;
  let mockDesertVerifier;
  let additionalZkBNB;
  let mockERC20;
  let zkBNB;
  let owner;
  let zkBNBImpl;
  let upgradeParams;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    [owner] = await ethers.getSigners();

    mockGovernance = await smock.fake('Governance');
    mockZkBNBVerifier = await smock.fake('ZkBNBVerifier');
    mockDesertVerifier = await smock.fake('DesertVerifier');
    mockERC20 = await smock.fake('ERC20');

    const AdditionalZkBNB = await ethers.getContractFactory('AdditionalZkBNB', {
      libraries: {},
    });
    additionalZkBNB = await AdditionalZkBNB.deploy();
    await additionalZkBNB.deployed();

    zkBNBImpl = await deployZkBNB('ZkBNB');

    const initParams = ethers.utils.defaultAbiCoder.encode(
      ['address', 'address', 'address', 'address', 'bytes32'],
      [
        mockGovernance.address,
        mockZkBNBVerifier.address,
        additionalZkBNB.address,
        mockDesertVerifier.address,
        '0x0000000000000000000000000000000000000000000000000000000000000000',
      ],
    );
    await expect(zkBNBImpl.initialize(initParams)).to.be.revertedWith('Can not dirctly call by zkbnbImplementation');
    upgradeParams = ethers.utils.defaultAbiCoder.encode(
      ['address', 'address'],
      [additionalZkBNB.address, additionalZkBNB.address],
    );
    await expect(zkBNBImpl.upgrade(upgradeParams)).to.be.revertedWith('Can not dirctly call by zkbnbImplementation');

    zkBNB = await deployZkBNBProxy(initParams, zkBNBImpl);
  });

  describe('Deposit', function () {
    const toAddress = '0xB4fdA33E65656F9f485438ABd9012eD04a31E006';

    describe('deposit BNB', async function () {
      it('should reverted if insufficient', async () => {
        await expect(zkBNB.depositBNB(toAddress, { value: 0 })).to.be.revertedWith('ia');
      });

      it('should reverted if toAddress is zero address', async () => {
        await expect(zkBNB.depositBNB(ethers.constants.AddressZero, { value: 100 })).to.be.revertedWith('ib');
      });

      it('should increase totalOpenPriorityRequests', async () => {
        const totalBefore = await zkBNB.totalOpenPriorityRequests();
        await zkBNB.depositBNB(toAddress, { value: 10 });
        await zkBNB.depositBNB(toAddress, { value: 10 });
        await zkBNB.depositBNB(toAddress, { value: 10 });
        const totalAfter = await zkBNB.totalOpenPriorityRequests();

        expect(totalAfter).to.be.equal(totalBefore + 3);
      });

      it('should emit `Deposit` events', async () => {
        const pubData = encodePubData(PubDataTypeMap[PubDataType.Deposit], [
          PubDataType.Deposit,
          0,
          '0xB4fdA33E65656F9f485438ABd9012eD04a31E006',
          3,
          10,
        ]);

        await expect(zkBNB.depositBNB(toAddress, { value: 10 }))
          .to.emit(zkBNB, 'NewPriorityRequest')
          .withArgs(owner.address, 0, PubDataType.Deposit, pubData, 201604)
          .to.emit(zkBNB, 'Deposit')
          .withArgs(0, toAddress, 10);
      });
    });
    describe('deposit ERC20', async function () {
      it('should reverted', async () => {
        // amount check
        await expect(zkBNB.depositBEP20(mockERC20.address, 0, toAddress)).to.be.revertedWith('I');

        // assets must exist
        mockGovernance.validateAssetAddress.returns(2);
        mockGovernance.pausedAssets.returns(true);
        await expect(zkBNB.depositBEP20(mockERC20.address, 10, toAddress)).to.be.revertedWith('b');

        // insufficient
        mockGovernance.pausedAssets.returns(false);
        mockERC20.transferFrom.returns(true);
        mockERC20.balanceOf.returnsAtCall(0, 100);
        mockERC20.balanceOf.returnsAtCall(1, 100);

        await expect(zkBNB.depositBEP20(mockERC20.address, 10, toAddress)).to.be.revertedWith('D');

        // toAddress should not be zero address
        await expect(zkBNB.depositBEP20(mockERC20.address, 10, ethers.constants.AddressZero)).to.be.revertedWith('ib');
      });

      it('should transfer erc20', async () => {
        mockERC20.transferFrom.returns(true);
        mockGovernance.pausedAssets.returns(false);
        mockERC20.balanceOf.returnsAtCall(0, 100);
        mockERC20.balanceOf.returnsAtCall(1, 110);
        await zkBNB.depositBEP20(mockERC20.address, 10, toAddress);

        expect(mockERC20.transferFrom).to.have.been.calledWith(owner.address, zkBNB.address, 10);
      });

      it('should emit `Deposit` event', async () => {
        const ASSET_ID = 3;
        mockERC20.transferFrom.returns(true);
        mockGovernance.validateAssetAddress.returns(ASSET_ID);
        mockGovernance.pausedAssets.returns(false);
        mockERC20.balanceOf.returnsAtCall(0, 100);
        mockERC20.balanceOf.returnsAtCall(1, 110);

        const pubData = encodePubData(PubDataTypeMap[PubDataType.Deposit], [
          PubDataType.Deposit,
          0,
          '0xB4fdA33E65656F9f485438ABd9012eD04a31E006',
          ASSET_ID,
          10,
        ]);
        await expect(zkBNB.depositBEP20(mockERC20.address, 10, toAddress))
          .to.emit(zkBNB, 'NewPriorityRequest')
          .withArgs(owner.address, 0, PubDataType.Deposit, pubData, 201604)
          .to.emit(zkBNB, 'Deposit')
          .withArgs(ASSET_ID, toAddress, 10);
      });
    });
  });

  describe('Upgrade', function () {
    const toAddress = '0xB4fdA33E65656F9f485438ABd9012eD04a31E006';

    beforeEach(async function () {
      // test upgradeTarget
      const Proxy = await ethers.getContractFactory('Proxy');
      const zkBNBProxy = Proxy.attach(zkBNB.address);
      await zkBNBProxy.upgradeTarget(zkBNBImpl.address, upgradeParams);
    });

    describe('deposit BNB', async function () {
      it('should reverted if insufficient', async () => {
        await expect(zkBNB.depositBNB(toAddress, { value: 0 })).to.be.revertedWith('ia');
      });

      it('should reverted if toAddress is zero address', async () => {
        await expect(zkBNB.depositBNB(ethers.constants.AddressZero, { value: 100 })).to.be.revertedWith('ib');
      });

      it('should increase totalOpenPriorityRequests', async () => {
        const totalBefore = await zkBNB.totalOpenPriorityRequests();
        await zkBNB.depositBNB(toAddress, { value: 10 });
        await zkBNB.depositBNB(toAddress, { value: 10 });
        await zkBNB.depositBNB(toAddress, { value: 10 });
        const totalAfter = await zkBNB.totalOpenPriorityRequests();

        expect(totalAfter).to.be.equal(totalBefore + 3);
      });

      it('should emit `Deposit` events', async () => {
        const pubData = encodePubData(PubDataTypeMap[PubDataType.Deposit], [
          PubDataType.Deposit,
          0,
          '0xB4fdA33E65656F9f485438ABd9012eD04a31E006',
          3,
          10,
        ]);

        await expect(zkBNB.depositBNB(toAddress, { value: 10 }))
          .to.emit(zkBNB, 'NewPriorityRequest')
          .withArgs(owner.address, 0, PubDataType.Deposit, pubData, 201604)
          .to.emit(zkBNB, 'Deposit')
          .withArgs(0, toAddress, 10);
      });
    });
    describe('deposit ERC20', async function () {
      it('should reverted', async () => {
        // amount check
        await expect(zkBNB.depositBEP20(mockERC20.address, 0, toAddress)).to.be.revertedWith('I');

        // assets must exist
        mockGovernance.validateAssetAddress.returns(2);
        mockGovernance.pausedAssets.returns(true);
        await expect(zkBNB.depositBEP20(mockERC20.address, 10, toAddress)).to.be.revertedWith('b');

        // insufficient
        mockGovernance.pausedAssets.returns(false);
        mockERC20.transferFrom.returns(true);
        mockERC20.balanceOf.returnsAtCall(0, 100);
        mockERC20.balanceOf.returnsAtCall(1, 100);

        await expect(zkBNB.depositBEP20(mockERC20.address, 10, toAddress)).to.be.revertedWith('D');

        // toAddress should not be zero address
        await expect(zkBNB.depositBEP20(mockERC20.address, 10, ethers.constants.AddressZero)).to.be.revertedWith('ib');
      });

      it('should transfer erc20', async () => {
        mockERC20.transferFrom.returns(true);
        mockGovernance.pausedAssets.returns(false);
        mockERC20.balanceOf.returnsAtCall(0, 100);
        mockERC20.balanceOf.returnsAtCall(1, 110);
        await zkBNB.depositBEP20(mockERC20.address, 10, toAddress);

        expect(mockERC20.transferFrom).to.have.been.calledWith(owner.address, zkBNB.address, 10);
      });

      it('should emit `Deposit` event', async () => {
        const ASSET_ID = 3;
        mockERC20.transferFrom.returns(true);
        mockGovernance.validateAssetAddress.returns(ASSET_ID);
        mockGovernance.pausedAssets.returns(false);
        mockERC20.balanceOf.returnsAtCall(0, 100);
        mockERC20.balanceOf.returnsAtCall(1, 110);

        const pubData = encodePubData(PubDataTypeMap[PubDataType.Deposit], [
          PubDataType.Deposit,
          0,
          '0xB4fdA33E65656F9f485438ABd9012eD04a31E006',
          ASSET_ID,
          10,
        ]);
        await expect(zkBNB.depositBEP20(mockERC20.address, 10, toAddress))
          .to.emit(zkBNB, 'NewPriorityRequest')
          .withArgs(owner.address, 0, PubDataType.Deposit, pubData, 201604)
          .to.emit(zkBNB, 'Deposit')
          .withArgs(ASSET_ID, toAddress, 10);
      });
    });
  });
});
