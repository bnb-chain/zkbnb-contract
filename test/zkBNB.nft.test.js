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

  let owner, acc1, acc2;

  const mockHash = ethers.utils.hexZeroPad(ethers.utils.hexlify(1), 32); // mock data

  before(async function () {
    [owner, acc1, acc2] = await ethers.getSigners();
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

  it('check default NFT Factory', async function () {
    expect(await zkBNB.defaultNFTFactory()).to.equal(mockNftFactory.address);
  });

  describe('withdraw and mint a NFT', function () {
    const mockNftIndex = 0;

    it('NFT is not minted before withdrawal', async function () {
      const nftKey = ethers.utils.keccak256(abi.encode(['address', 'uint256'], [mockNftFactory.address, mockNftIndex]));
      const _l2Nft = await zkBNB.getMintedL2NftInfo(nftKey);

      expect(_l2Nft['nftContentHash']).to.equal(ethers.utils.hexZeroPad(ethers.utils.hexlify(0), 32));
    });

    it('should done mint and then withdraw', async function () {
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
        nftContentHash: mockHash,
        creatorAccountNameHash: mockHash,
        collectionId: 0,
      };

      await expect(await zkBNB.testWithdrawOrStoreNFT(withdrawOp))
        .to.emit(zkBNB, 'WithdrawNft')
        .withArgs(1, mockNftFactory.address, acc1.address, mockNftIndex);
    });

    it('NFT should be minted', async function () {
      const nftKey = ethers.utils.keccak256(abi.encode(['address', 'uint256'], [mockNftFactory.address, mockNftIndex]));
      const l2Nft = await zkBNB.getMintedL2NftInfo(nftKey);

      expect(l2Nft['nftIndex']).to.equal(mockNftIndex);
      expect(l2Nft['creatorAccountIndex']).to.equal(0);
      expect(l2Nft['creatorTreasuryRate']).to.equal(5);
      expect(l2Nft['nftContentHash']).to.equal(mockHash);
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
        toAddress: acc2.address,
        gasFeeAccountIndex: 1,
        gasFeeAssetId: 0, //BNB
        gasFeeAssetAmount: 666,
        nftContentHash: mockHash,
        creatorAccountNameHash: mockHash,
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

    it('the NFT should not be minted', async function () {
      const nftKey = ethers.utils.keccak256(abi.encode(['address', 'uint256'], [mockNftFactory.address, nftIndex]));
      const l2Nft = await zkBNB.getMintedL2NftInfo(nftKey);

      assert.equal(l2Nft['nftContentHash'], 0);
      assert.equal(l2Nft['nftIndex'], 0);
    });

    it('withdraw should succeed on retry', async function () {
      mockZNSController.getOwner.returns(acc1.address);
      mockNftFactory.mintFromZkBNB.returns();

      await expect(await zkBNB.withdrawPendingNFTBalance(nftIndex))
        .to.emit(zkBNB, 'WithdrawNft')
        .withArgs(1, mockNftFactory.address, acc2.address, nftIndex);

      expect(await mockNftFactory.ownerOf(nftIndex)).to.equal(acc2.address);
      expect(await mockNftFactory.balanceOf(acc2.address)).to.equal(1);
    });

    it('the NFT should be minted after withdrawal', async function () {
      const nftKey = ethers.utils.keccak256(abi.encode(['address', 'uint256'], [mockNftFactory.address, nftIndex]));
      const result = await zkBNB.getMintedL2NftInfo(nftKey);

      assert.equal(result['nftContentHash'], mockHash);
      assert.equal(result['nftIndex'], nftIndex);
    });

    it('the NFT should not be pending after withdrawal', async function () {
      const result = await zkBNB.getPendingWithdrawnNFT(nftIndex);
      assert.equal(result['nftContentHash'], 0);
      assert.equal(result['nftIndex'], 0);
    });
  });

  describe('deposit NFT', async function () {
    const nftL1TokenId = 0;

    it('deposit the 1st withdrawn NFT', async function () {
      mockZNSController.getSubnodeNameHash.returns();
      mockZNSController.isRegisteredNameHash.returns(true);

      await mockNftFactory.connect(acc1).setApprovalForAll(zkBNB.address, true);
      await expect(await zkBNB.desertMode()).to.equal(false);
      await expect(await zkBNB.connect(acc1).depositNft('accountName', mockNftFactory.address, nftL1TokenId))
        .to.emit(zkBNB, 'DepositNft')
        .withArgs(ethers.constants.HashZero, mockHash, mockNftFactory.address, nftL1TokenId, 0);
    });

    it('the deposit priority request should be added', async function () {
      const firstPriorityRequestId = await zkBNB.firstPriorityRequestId();
      const totalOpenPriorityRequests = await zkBNB.totalOpenPriorityRequests();
      const depositRequestId = firstPriorityRequestId + totalOpenPriorityRequests - 1;
      const {
        hashedPubData: _hashedPubData,
        expirationBlock: _expirationBlock,
        txType: _txType,
      } = await zkBNB.getPriorityRequest(depositRequestId);

      // // TODO: check hashed pubdata
      // const expectPubData = ethers.utils.solidityPack(
      //   ['uint8', 'uint32', 'uint40', 'uint32', 'uint16', 'bytes32', 'bytes32', 'uint16'],
      //   [3, 0, nftL1TokenId, 0, 5, mockHash, ethers.constants.HashZero, 0],
      // );
      // assert.equal(_hashedPubData, expectPubData);

      assert.equal(_txType, 3);
    });

    it('the nft should be deleted from L1 account after deposition', async function () {
      const nfts = await zkBNB.getAccountNfts(acc1.address);
      expect(nfts).to.be.an('array').that.is.empty;
    });

    it('should fail to deposit a NFT which is not created by layer2', async function () {
      const mock721 = await smock.fake('ZkBNBRelatedERC721');
      mock721.ownerOf.returns(zkBNB.address);

      expect(zkBNB.depositNft('_accountName', mock721.address, '2')).to.be.revertedWith('l1 nft is not allowed');
    });
  });

  it.skip('request Full Exit Nft', async function () {});
});
