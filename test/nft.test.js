const chai = require('chai');
const { ethers } = require('hardhat');
const { smock } = require('@defi-wonderland/smock');
const assert = require('assert');

const { expect } = chai;
chai.use(smock.matchers);
const abi = ethers.utils.defaultAbiCoder;

describe('NFT functionality', function () {
  let mockGovernance;
  let mockZkBNBVerifier;
  let mockZNSController;
  let mockPublicResolver;
  let mockNftFactory;

  let zkBNB; // ZkBNBTest.sol
  let additionalZkBNB; // AdditionalZkBNB.sol
  let ERC721;

  let owner, acc1;

  const mockhash = ethers.utils.hexZeroPad(ethers.utils.hexlify(1), 32); // mock data

  before(async function () {
    [owner, acc1] = await ethers.getSigners();
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

    const AdditionalZkBNB = await ethers.getContractFactory('AdditionalZkBNB');
    additionalZkBNB = await AdditionalZkBNB.deploy();
    await additionalZkBNB.deployed();

    const Utils = await ethers.getContractFactory('Utils');
    utils = await Utils.deploy();
    await utils.deployed();

    const ZkBNBTest = await ethers.getContractFactory('ZkBNBTest', {
      libraries: {
        Utils: utils.address,
      },
    });
    zkBNB = await ZkBNBTest.deploy(
      mockGovernance.address,
      mockZkBNBVerifier.address,
      additionalZkBNB.address,
      mockZNSController.address,
      mockPublicResolver.address,
    );
    await zkBNB.deployed();

    const MockNftFactory = await smock.mock('ZkBNBNFTFactory');
    mockNftFactory = await MockNftFactory.deploy('FooNFT', 'FOO', 'ipfs://', zkBNB.address);
    await mockNftFactory.deployed();

    await zkBNB.testSetDefaultNFTFactory(mockNftFactory.address);
  });

  it('get NFT Factory', async function () {
    expect(await zkBNB.defaultNFTFactory()).to.equal(mockNftFactory.address);
  });

  it.skip('register NFT Factory', async function () {});

  describe('withdraw and mint a NFT', function () {
    const mockNftIndex = 0;

    it('NFT is not there before `withdraw', async function () {
      const nftKey = ethers.utils.keccak256(abi.encode(['address', 'uint256'], [mockNftFactory.address, mockNftIndex]));
      const _l2Nft = await zkBNB.getL2NftInfo(nftKey);

      expect(_l2Nft['nftContentHash']).to.equal(ethers.utils.hexZeroPad(ethers.utils.hexlify(0), 32));
    });

    it('should mint and then withdraw', async function () {
      mockZNSController.getOwner.returns(acc1.address);

      const withdrawOp = {
        txType: 11, // WithdrawNft
        fromAccountIndex: 1,
        creatorAccountIndex: 0,
        creatorTreasuryRate: 5,
        nftIndex: mockNftIndex,
        toAddress: acc1.address,
        gasFeeAccountIndex: 1,
        gasFeeAssetId: 0, //BNB
        gasFeeAssetAmount: 666,
        nftContentHash: mockhash,
        creatorAccountNameHash: mockhash,
        collectionId: 0,
      };

      await expect(await zkBNB.testWithdrawOrStoreNFT(withdrawOp))
        .to.emit(zkBNB, 'WithdrawNft')
        .withArgs(1, mockNftFactory.address, acc1.address, mockNftIndex);
    });

    it('NFT should be minted', async function () {
      const nftKey = ethers.utils.keccak256(abi.encode(['address', 'uint256'], [mockNftFactory.address, mockNftIndex]));
      const l2Nft = await zkBNB.getL2NftInfo(nftKey);

      expect(l2Nft['nftIndex']).to.equal(mockNftIndex);
      expect(l2Nft['creatorAccountIndex']).to.equal(0);
      expect(l2Nft['creatorTreasuryRate']).to.equal(5);
      expect(l2Nft['nftContentHash']).to.equal(mockhash);
      expect(l2Nft['collectionId']).to.equal(0);
    });

    it('L1 NFT should be owned by acc1', async function () {
      expect(await mockNftFactory.ownerOf(mockNftIndex)).to.equal(acc1.address);
      expect(await mockNftFactory.balanceOf(acc1.address)).to.equal(1);
    });
  });

  describe('withdraw NFT on mint failure', async function () {
    const nftIndex = 2;

    it('store pending withdrawn NFT on mint failure', async function () {
      mockZNSController.getOwner.returns(acc1.address);
      mockNftFactory.mintFromZkBNB.reverts();

      const withdrawOp2 = {
        txType: 11, // WithdrawNft
        fromAccountIndex: 1,
        creatorAccountIndex: 0,
        creatorTreasuryRate: 5,
        nftIndex,
        toAddress: acc1.address,
        gasFeeAccountIndex: 1,
        gasFeeAssetId: 0, //BNB
        gasFeeAssetAmount: 666,
        nftContentHash: mockhash,
        creatorAccountNameHash: mockhash,
        collectionId: 0,
      };

      await expect(await zkBNB.testWithdrawOrStoreNFT(withdrawOp2))
        .to.emit(zkBNB, 'WithdrawalNFTPending')
        .withArgs(nftIndex);

      const result = await zkBNB.getPendingWithdrawnNFT(nftIndex);

      assert.deepStrictEqual(withdrawOp2, {
        txType: result['txType'],
        fromAccountIndex: result['fromAccountIndex'],
        creatorAccountIndex: result['creatorAccountIndex'],
        creatorTreasuryRate: result['creatorTreasuryRate'],
        nftIndex: result['nftIndex'],
        toAddress: result['toAddress'],
        gasFeeAccountIndex: result['gasFeeAccountIndex'],
        gasFeeAssetId: result['gasFeeAssetId'],
        gasFeeAssetAmount: result['gasFeeAssetAmount'],
        nftContentHash: result['nftContentHash'],
        creatorAccountNameHash: result['creatorAccountNameHash'],
        collectionId: result['collectionId'],
      });
    });

    it('NFT should not be minted', async function () {
      const nftKey = ethers.utils.keccak256(abi.encode(['address', 'uint256'], [mockNftFactory.address, nftIndex]));
      const l2Nft = await zkBNB.getL2NftInfo(nftKey);
      assert.equal(l2Nft['nftContentHash'], 0);
    });

    it('withdraw pending NFT balance', async function () {
      mockZNSController.getOwner.returns(acc1.address);

      await zkBNB.withdrawPendingNFTBalance(nftIndex);

      const { nftContentHash: _nftContentHash } = await zkBNB.getPendingWithdrawnNFT(nftIndex);

      assert.equal(_nftContentHash, 0);

      await expect(await zkBNB.withdrawPendingNFTBalance(nftIndex))
        .to.emit(zkBNB, 'WithdrawNft')
        .withArgs(1, mockNftFactory.address, acc1.address, nftIndex);

      const result = await zkBNB.withdrawPendingNFTBalance(nftIndex);
    });
  });

  it.skip('deposit NFT', async function () {});

  it.skip('request Full Exit Nft', async function () {});
});
