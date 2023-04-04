const chai = require('chai');
const { ethers } = require('hardhat');
const { smock } = require('@defi-wonderland/smock');
const { PubDataType, encodePubData, PubDataTypeMap } = require('./util');

const { expect } = chai;
chai.use(smock.matchers);

describe('ZkBNB', function () {
  let mockGovernance;
  let mockZkBNBVerifier;
  let mockDesertVerifier;
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
    mockDesertVerifier = await smock.fake('DesertVerifier');
    mockERC20 = await smock.fake('ERC20');
    mockERC721 = await smock.fake('ERC721');

    const Utils = await ethers.getContractFactory('Utils');
    utils = await Utils.deploy();
    await utils.deployed();

    const AdditionalZkBNB = await ethers.getContractFactory('AdditionalZkBNB', {
      libraries: {},
    });
    additionalZkBNB = await AdditionalZkBNB.deploy();
    await additionalZkBNB.deployed();

    const ZkBNB = await ethers.getContractFactory('ZkBNB', {
      libraries: {
        Utils: utils.address,
      },
    });
    zkBNB = await ZkBNB.deploy();
    await zkBNB.deployed();

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
    await zkBNB.initialize(initParams);
  });

  describe('Deposit', function () {
    const accountNameHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('accountNameHash'));
    const toAddress = '0xB4fdA33E65656F9f485438ABd9012eD04a31E006';

    describe('deposit BNB', async function () {
      it('should reverted if insufficient', async () => {
        await expect(zkBNB.depositBNB(toAddress, { value: 0 })).to.be.revertedWith('ia');
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
