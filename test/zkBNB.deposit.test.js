const chai = require('chai');
const { ethers } = require('hardhat');
const { smock } = require('@defi-wonderland/smock');
const { PubDataType, encodePubData, PubDataTypeMap } = require('./util');

const { expect } = chai;
chai.use(smock.matchers);

describe('ZkBNB', function () {
  let mockGovernance;
  let mockZkBNBVerifier;
  let mockZNSController;
  let mockPublicResolver;
  let additionalZkBNB;
  let mockERC20;
  let mockERC721;
  let zkBNB;
  let owner, addr1, addr2, addr3, addr4;

  // `ZkBNB` needs to link to library `Utils` before deployed
  let utils;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

    mockGovernance = await smock.fake('Governance');
    mockZkBNBVerifier = await smock.fake('ZkBNBVerifier');
    mockZNSController = await smock.fake('ZNSController');
    mockPublicResolver = await smock.fake('PublicResolver');
    mockERC20 = await smock.fake('ERC20');
    mockERC721 = await smock.fake('ERC721');

    const Utils = await ethers.getContractFactory('Utils');
    utils = await Utils.deploy();
    await utils.deployed();

    const AdditionalZkBNB = await ethers.getContractFactory('AdditionalZkBNB', {
      libraries: {
        Utils: utils.address,
      },
    });
    additionalZkBNB = await AdditionalZkBNB.deploy();
    await additionalZkBNB.deployed();

    const NftHelperLibrary = await ethers.getContractFactory('NftHelperLibrary');
    const nftHelperLibrary = await NftHelperLibrary.deploy();
    const ZkBNB = await ethers.getContractFactory('ZkBNB', {
      libraries: {
        NftHelperLibrary: nftHelperLibrary.address,
      },
    });
    zkBNB = await ZkBNB.deploy();
    await zkBNB.deployed();

    const initParams = ethers.utils.defaultAbiCoder.encode(
      ['address', 'address', 'address', 'address', 'address', 'bytes32'],
      [
        mockGovernance.address,
        mockZkBNBVerifier.address,
        additionalZkBNB.address,
        mockZNSController.address,
        mockPublicResolver.address,
        '0x0000000000000000000000000000000000000000000000000000000000000000',
      ],
    );
    await zkBNB.initialize(initParams);
  });

  describe('Deposit', function () {
    const accountNameHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('accountNameHash'));

    describe('deposit BNB', async function () {
      it('should reverted if insufficient', async () => {
        await expect(zkBNB.depositBNB('account', { value: 0 })).to.be.revertedWith('ia');
      });
      it('should reverted if account name not registered', async () => {
        mockZNSController.isRegisteredNameHash.returns(false);
        await expect(zkBNB.depositBNB('account', { value: 10 })).to.be.revertedWith('nr');
      });
      it('should increase totalOpenPriorityRequests', async () => {
        mockZNSController.isRegisteredNameHash.returns(true);
        const totalBefore = await zkBNB.totalOpenPriorityRequests();
        await zkBNB.depositBNB('account', { value: 10 });
        await zkBNB.depositBNB('account', { value: 10 });
        await zkBNB.depositBNB('account', { value: 10 });
        const totalAfter = await zkBNB.totalOpenPriorityRequests();

        expect(totalAfter).to.be.equal(totalBefore + 3);
      });
      it('should emit `Deposit` events', async () => {
        mockZNSController.isRegisteredNameHash.returns(true);
        mockZNSController.getSubnodeNameHash.returns(accountNameHash);

        const pubData = encodePubData(PubDataTypeMap[PubDataType.Deposit], [
          PubDataType.Deposit,
          0,
          0,
          10,
          accountNameHash,
        ]);

        await expect(zkBNB.depositBNB('account', { value: 10 }))
          .to.emit(zkBNB, 'NewPriorityRequest')
          .withArgs(owner.address, 0, PubDataType.Deposit, pubData, 201604)
          .to.emit(zkBNB, 'Deposit')
          .withArgs(0, accountNameHash, 10);
      });
    });
    describe('deposit ERC20', async function () {
      it('should reverted', async () => {
        // amount check
        await expect(zkBNB.depositBEP20(mockERC20.address, 0, 'account')).to.be.revertedWith('I');

        // account must registered
        mockZNSController.isRegisteredNameHash.returns(false);
        await expect(zkBNB.depositBEP20(mockERC20.address, 10, 'account')).to.be.revertedWith('N');

        // assets must exist
        mockGovernance.validateAssetAddress.returns(2);
        mockGovernance.pausedAssets.returns(true);
        mockZNSController.isRegisteredNameHash.returns(true);
        await expect(zkBNB.depositBEP20(mockERC20.address, 10, 'account')).to.be.revertedWith('b');

        // insufficient
        mockGovernance.pausedAssets.returns(false);
        mockERC20.transferFrom.returns(true);
        mockERC20.balanceOf.returnsAtCall(0, 100);
        mockERC20.balanceOf.returnsAtCall(1, 100);
        await expect(zkBNB.depositBEP20(mockERC20.address, 10, 'account')).to.be.revertedWith('D');
      });
      it('should transfer erc20', async () => {
        mockERC20.transferFrom.returns(true);
        mockZNSController.isRegisteredNameHash.returns(true);
        mockGovernance.pausedAssets.returns(false);
        mockERC20.balanceOf.returnsAtCall(0, 100);
        mockERC20.balanceOf.returnsAtCall(1, 110);
        await zkBNB.depositBEP20(mockERC20.address, 10, 'account');

        expect(mockERC20.transferFrom).to.have.been.calledWith(owner.address, zkBNB.address, 10);
      });
      it('should emit `Deposit` event', async () => {
        const ASSET_ID = 3;
        mockZNSController.getSubnodeNameHash.returns(accountNameHash);
        mockERC20.transferFrom.returns(true);
        mockZNSController.isRegisteredNameHash.returns(true);
        mockGovernance.validateAssetAddress.returns(ASSET_ID);
        mockGovernance.pausedAssets.returns(false);
        mockERC20.balanceOf.returnsAtCall(0, 100);
        mockERC20.balanceOf.returnsAtCall(1, 110);

        const pubData = encodePubData(PubDataTypeMap[PubDataType.Deposit], [
          PubDataType.Deposit,
          0,
          ASSET_ID,
          10,
          accountNameHash,
        ]);
        await expect(zkBNB.depositBEP20(mockERC20.address, 10, 'account'))
          .to.emit(zkBNB, 'NewPriorityRequest')
          .withArgs(owner.address, 0, PubDataType.Deposit, pubData, 201604)
          .to.emit(zkBNB, 'Deposit')
          .withArgs(ASSET_ID, accountNameHash, 10);
      });
    });
  });
});
