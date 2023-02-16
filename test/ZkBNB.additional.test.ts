import { ethers } from 'hardhat';
import chai, { expect } from 'chai';
import { smock } from '@defi-wonderland/smock';

import {
  CommitBlockInfo,
  EMPTY_STRING_KECCAK,
  PubDataType,
  PubDataTypeMap,
  StoredBlockInfo,
  VerifyAndExecuteBlockInfo,
  encodePackPubData,
  hashStoredBlockInfo,
  padEndBytes121,
} from './util';

chai.use(smock.matchers);

describe('ZkBNB', function () {
  let mockGovernance;
  let mockZkBNBVerifier;
  let mockZNSController;
  let mockPublicResolver;
  let mockERC20;
  let mockERC721;
  let mockNftFactory;
  let zkBNB;
  let additionalZkBNB;
  let owner, addr1, addr2, addr3, addr4;
  const accountNameHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('accountNameHash'));

  const genesisStateRoot = ethers.utils.formatBytes32String('genesisStateRoot');
  const commitment = ethers.utils.formatBytes32String('');
  const genesisBlock: StoredBlockInfo = {
    blockSize: 0,
    blockNumber: 0,
    priorityOperations: 0,
    pendingOnchainOperationsHash: EMPTY_STRING_KECCAK,
    timestamp: 0,
    stateRoot: genesisStateRoot,
    commitment,
  };

  // `ZkBNB` needs to link to library `Utils` before deployed
  let utils;
  const newStateRoot = ethers.utils.formatBytes32String('newStateRoot');

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

    mockNftFactory = await smock.fake('ZkBNBNFTFactory');

    const Utils = await ethers.getContractFactory('Utils');
    utils = await Utils.deploy();
    await utils.deployed();

    const AdditionalZkBNB = await ethers.getContractFactory('AdditionalZkBNBTest', {
      libraries: {
        Utils: utils.address,
      },
    });
    additionalZkBNB = await AdditionalZkBNB.deploy(ethers.constants.AddressZero, ethers.constants.AddressZero);
    await additionalZkBNB.deployed();

    const ZkBNB = await ethers.getContractFactory('ZkBNBTest');
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
        genesisStateRoot,
      ],
    );
    await zkBNB.initialize(initParams);

    await zkBNB.setDefaultNFTFactory(mockNftFactory.address);
  });

  describe('commit blocks', function () {
    const nftContentHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('nftContentHash'));
    const ASSET_ID = 3;
    const TOKEN_ID = 3;

    it('should be zero block when initialize it', async () => {
      const res = await zkBNB.storedBlockHashes(0);
      expect(res).to.be.equal(hashStoredBlockInfo(genesisBlock));
    });
    describe('Priority Operations', () => {
      // initiated on the BSC by an BNB Smart Chain account
      let pubDataDeposit, pubDataDeposit20;
      beforeEach(async function () {
        pubDataDeposit = encodePackPubData(PubDataTypeMap[PubDataType.Deposit], [
          PubDataType.Deposit,
          0,
          0,
          10,
          accountNameHash,
        ]);

        pubDataDeposit20 = encodePackPubData(PubDataTypeMap[PubDataType.Deposit], [
          PubDataType.Deposit,
          0,
          ASSET_ID,
          10,
          accountNameHash,
        ]);
      });
      it('should revert if use unsupported type', async () => {
        const pubData = encodePackPubData(PubDataTypeMap[PubDataType.Deposit], [20, 0, 0, 10, accountNameHash]);
        const commitBlock: CommitBlockInfo = {
          newStateRoot,
          publicData: ethers.utils.hexConcat([pubData]),
          timestamp: Date.now(),
          publicDataOffsets: [0, 121],
          blockNumber: 1,
          blockSize: 2,
        };
        await expect(zkBNB.commitBlocks(genesisBlock, [commitBlock])).to.be.reverted;
      });
      it('should revert if user is not operating on the chain', async () => {
        const commitBlock: CommitBlockInfo = {
          newStateRoot,
          publicData: ethers.utils.hexConcat([pubDataDeposit, pubDataDeposit20]),
          timestamp: Date.now(),
          publicDataOffsets: [0, 121],
          blockNumber: 1,
          blockSize: 2,
        };
        await expect(zkBNB.commitBlocks(genesisBlock, [commitBlock])).to.be.reverted;
      });
      it('should revert if block number is wrong', async () => {
        mockZNSController.isRegisteredNameHash.returns(true);
        mockZNSController.getSubnodeNameHash.returns(accountNameHash);

        await zkBNB.depositBNB('accountNameHash', { value: 10 });

        mockZNSController.getSubnodeNameHash.returns(accountNameHash);
        mockERC20.transferFrom.returns(true);
        mockZNSController.isRegisteredNameHash.returns(true);
        mockGovernance.validateAssetAddress.returns(ASSET_ID);
        mockGovernance.pausedAssets.returns(false);
        mockERC20.balanceOf.returnsAtCall(0, 100);
        mockERC20.balanceOf.returnsAtCall(1, 110);

        await zkBNB.depositBEP20(mockERC20.address, 10, 'accountNameHash');

        const commitBlock: CommitBlockInfo = {
          newStateRoot,
          publicData: ethers.utils.hexConcat([pubDataDeposit, pubDataDeposit20]),
          timestamp: Date.now(),
          publicDataOffsets: [0, 121],
          blockNumber: 2,
          blockSize: 3,
        };
        await expect(zkBNB.commitBlocks(genesisBlock, [commitBlock])).to.be.reverted;
      });
      it('should can commit register ZNS operation', async () => {
        mockZNSController.registerZNS.returns([accountNameHash, 1]);
        const pubKeyX = ethers.utils.formatBytes32String('pubKeyX');
        const pubKeyY = ethers.utils.formatBytes32String('pubKeyY');

        const tx = await zkBNB.registerZNS('accountName', owner.address, pubKeyX, pubKeyY);

        const receipt = await tx.wait();
        const event = receipt.events.find((event) => {
          return event.event === 'NewPriorityRequest';
        });
        const pubDataRegisterZNS = event.args[3];

        const commitBlock: CommitBlockInfo = {
          newStateRoot,
          publicData: ethers.utils.hexConcat([pubDataRegisterZNS]),
          timestamp: Date.now(),
          publicDataOffsets: [0],
          blockNumber: 1,
          blockSize: 2,
        };
        await expect(zkBNB.commitBlocks(genesisBlock, [commitBlock]))
          .to.emit(zkBNB, 'BlockCommit')
          .withArgs(1);
      });
      it('should can commit deposit operation', async () => {
        mockZNSController.isRegisteredNameHash.returns(true);
        mockZNSController.getSubnodeNameHash.returns(accountNameHash);

        await zkBNB.depositBNB('accountNameHash', { value: 10 });

        mockZNSController.getSubnodeNameHash.returns(accountNameHash);
        mockERC20.transferFrom.returns(true);
        mockZNSController.isRegisteredNameHash.returns(true);
        mockGovernance.validateAssetAddress.returns(ASSET_ID);
        mockGovernance.pausedAssets.returns(false);
        mockERC20.balanceOf.returnsAtCall(0, 100);
        mockERC20.balanceOf.returnsAtCall(1, 110);

        await zkBNB.depositBEP20(mockERC20.address, 10, 'accountNameHash');

        const commitBlock: CommitBlockInfo = {
          newStateRoot,
          publicData: ethers.utils.hexConcat([pubDataDeposit, pubDataDeposit20]),
          timestamp: Date.now(),
          publicDataOffsets: [0, 121],
          blockNumber: 1,
          blockSize: 2,
        };
        await expect(zkBNB.commitBlocks(genesisBlock, [commitBlock]))
          .to.emit(zkBNB, 'BlockCommit')
          .withArgs(1);
      });
      it('should can commit fullExit operation', async () => {
        // mock user request full exit, and get pubData
        mockZNSController.isRegisteredNameHash.returns(true);
        mockZNSController.getSubnodeNameHash.returns(accountNameHash);
        mockZNSController.getOwner.returns(owner.address);

        const tx = await zkBNB.requestFullExit('accountNameHash', ethers.constants.AddressZero);
        const receipt = await tx.wait();

        const event = receipt.events.find((event) => {
          return event.event === 'NewPriorityRequest';
        });
        const pubDataFullExit = event.args[3];

        const commitBlock: CommitBlockInfo = {
          newStateRoot,
          publicData: ethers.utils.hexConcat([padEndBytes121(pubDataFullExit)]),
          timestamp: Date.now(),
          publicDataOffsets: [0],
          blockNumber: 1,
          blockSize: 1,
        };
        await expect(zkBNB.commitBlocks(genesisBlock, [commitBlock]))
          .to.emit(zkBNB, 'BlockCommit')
          .withArgs(1);
      });
      describe('NFT', async () => {
        const nftL1TokenId = 0;
        const mockHash = ethers.utils.formatBytes32String('mock hash');
        beforeEach(async () => {
          mockZNSController.getOwner.returns(owner.address);

          const withdrawOp = {
            txType: 11, // WithdrawNft
            fromAccountIndex: 1,
            creatorAccountIndex: 0,
            creatorTreasuryRate: 5,
            nftIndex: nftL1TokenId,
            toAddress: owner.address,
            gasFeeAccountIndex: 1,
            gasFeeAssetId: 0, //BNB
            gasFeeAssetAmount: 666,
            nftContentHash: mockHash,
            creatorAccountNameHash: mockHash,
            collectionId: 0,
          };

          await zkBNB.testWithdrawOrStoreNFT(withdrawOp);
        });
        it.skip('should can commit deposit NFT operation', async () => {
          mockZNSController.isRegisteredNameHash.returns(true);
          mockZNSController.getSubnodeNameHash.returns(accountNameHash);
          mockZNSController.getSubnodeNameHash.returns();
          mockZNSController.isRegisteredNameHash.returns(true);
          mockNftFactory.ownerOf.returns(zkBNB.address);

          const tx = await zkBNB.depositNft('accountName', mockNftFactory.address, nftL1TokenId);

          const receipt = await tx.wait();
          const event = receipt.events.find((event) => {
            return event.event === 'NewPriorityRequest';
          });
          const pubDataDepositNft = event.args[3];

          const commitBlock: CommitBlockInfo = {
            newStateRoot,
            publicData: ethers.utils.hexConcat([padEndBytes121(pubDataDepositNft)]),
            timestamp: Date.now(),
            publicDataOffsets: [0],
            blockNumber: 1,
            blockSize: 1,
          };
          await expect(zkBNB.commitBlocks(genesisBlock, [commitBlock]))
            .to.emit(zkBNB, 'BlockCommit')
            .withArgs(1);
        });
        it('should can commit fullExitNFT operation', async () => {
          mockZNSController.isRegisteredNameHash.returns(true);
          mockZNSController.getSubnodeNameHash.returns(accountNameHash);
          mockZNSController.getSubnodeNameHash.returns();
          mockZNSController.isRegisteredNameHash.returns(true);
          mockNftFactory.ownerOf.returns(zkBNB.address);

          const tx = await zkBNB.requestFullExitNft('accountName', nftL1TokenId);

          const receipt = await tx.wait();
          const event = receipt.events.find((event) => {
            return event.event === 'NewPriorityRequest';
          });
          const pubDataDepositNft = event.args[3];

          const commitBlock: CommitBlockInfo = {
            newStateRoot,
            publicData: ethers.utils.hexConcat([padEndBytes121(pubDataDepositNft)]),
            timestamp: Date.now(),
            publicDataOffsets: [0],
            blockNumber: 1,
            blockSize: 1,
          };
          await expect(zkBNB.commitBlocks(genesisBlock, [commitBlock]))
            .to.emit(zkBNB, 'BlockCommit')
            .withArgs(1);
        });
      });
    });
  });

  describe('verify and execute blocks', () => {
    // execute onchain operations if needed.(`Withdraw`, `WithdrawNft`, `FullExit`, `FullExitNft`)
    const nftL1TokenId = 1;
    let storedBlockInfo: StoredBlockInfo;
    const verifyAndExecuteBlockInfos: VerifyAndExecuteBlockInfo[] = [];
    let lastBlock;
    beforeEach(async () => {
      // mock
      mockZNSController.getOwner.returns(owner.address);
      mockZNSController.isRegisteredNameHash.returns(true);
      mockZNSController.getSubnodeNameHash.returns(accountNameHash);
      mockZNSController.isRegisteredNameHash.returns(true);
      mockNftFactory.ownerOf.returns(zkBNB.address);
      mockZNSController.registerZNS.returns([accountNameHash, 1]);

      // Pre-submit a block for every case
      // commit block #1 fullExit nft;
      let tx = await zkBNB.requestFullExitNft('accountName', nftL1TokenId);
      let receipt = await tx.wait();
      let event = receipt.events.find((event) => {
        return event.event === 'NewPriorityRequest';
      });

      const pubData = event.args[3];

      const commitBlock: CommitBlockInfo = {
        newStateRoot,
        publicData: ethers.utils.hexConcat([padEndBytes121(pubData)]),
        timestamp: Date.now(),
        publicDataOffsets: [0],
        blockNumber: 1,
        blockSize: 1,
      };
      lastBlock = await zkBNB.getLastCommittedBlockData(genesisBlock, commitBlock);
      await zkBNB.commitBlocks(genesisBlock, [commitBlock]);
      storedBlockInfo = {
        blockSize: lastBlock.blockSize,
        blockNumber: lastBlock.blockNumber,
        priorityOperations: lastBlock.priorityOperations,
        pendingOnchainOperationsHash: lastBlock.pendingOnchainOperationsHash,
        timestamp: lastBlock.timestamp,
        stateRoot: lastBlock.stateRoot,
        commitment: lastBlock.commitment,
      };
      verifyAndExecuteBlockInfos.push({
        blockHeader: storedBlockInfo,
        pendingOnchainOpsPubData: [commitBlock.publicData],
      });
      // commit block #2;
      tx = await zkBNB.requestFullExit('accountNameHash', ethers.constants.AddressZero);
      receipt = await tx.wait();

      event = receipt.events.find((event) => {
        return event.event === 'NewPriorityRequest';
      });
      const pubDataFullExit = event.args[3];
      const commitBlock2: CommitBlockInfo = {
        newStateRoot,
        publicData: ethers.utils.hexConcat([padEndBytes121(pubDataFullExit)]),
        timestamp: Date.now(),
        publicDataOffsets: [0],
        blockNumber: 2,
        blockSize: 1,
      };

      lastBlock = await zkBNB.getLastCommittedBlockData(storedBlockInfo, commitBlock2);
      await zkBNB.commitBlocks(storedBlockInfo, [commitBlock2]);

      storedBlockInfo = {
        blockSize: lastBlock.blockSize,
        blockNumber: lastBlock.blockNumber,
        priorityOperations: lastBlock.priorityOperations,
        pendingOnchainOperationsHash: lastBlock.pendingOnchainOperationsHash,
        timestamp: lastBlock.timestamp,
        stateRoot: lastBlock.stateRoot,
        commitment: lastBlock.commitment,
      };
      verifyAndExecuteBlockInfos.push({
        blockHeader: storedBlockInfo,
        pendingOnchainOpsPubData: [commitBlock2.publicData],
      });
    });
    it('should be executing block after committed', async () => {
      mockZkBNBVerifier.verifyBatchProofs.returns(true);
      let stateRoot = await zkBNB.stateRoot();
      let totalOpenPriorityRequests = await zkBNB.totalOpenPriorityRequests();
      let totalBlocksVerified = await zkBNB.totalBlocksVerified();
      let firstPriorityRequestId = await zkBNB.firstPriorityRequestId();

      expect(stateRoot).to.equal(genesisBlock.stateRoot);
      expect(totalOpenPriorityRequests).to.equal(2);
      expect(totalBlocksVerified).to.equal(0);
      expect(firstPriorityRequestId).to.equal(0);

      const proofs = new Array(16).fill(10);
      await zkBNB.verifyAndExecuteBlocks(verifyAndExecuteBlockInfos, proofs);

      stateRoot = await zkBNB.stateRoot();
      totalOpenPriorityRequests = await zkBNB.totalOpenPriorityRequests();
      totalBlocksVerified = await zkBNB.totalBlocksVerified();
      firstPriorityRequestId = await zkBNB.firstPriorityRequestId();

      expect(stateRoot).to.equal(lastBlock.stateRoot);
      expect(totalOpenPriorityRequests).to.equal(0);
      expect(totalBlocksVerified).to.equal(2);
      expect(firstPriorityRequestId).to.equal(2);
    });
    it('Should be verified in order', async () => {
      mockZkBNBVerifier.verifyBatchProofs.returns(true);
      const proofs = new Array(8).fill(10);
      await expect(zkBNB.verifyAndExecuteBlocks([verifyAndExecuteBlockInfos.pop()], proofs)).to.revertedWith('k');
    });

    it('Should only validate supported blocks', async () => {
      mockZkBNBVerifier.verifyBatchProofs.returns(true);
      mockZNSController.isRegisteredNameHash.returns(true);
      mockZNSController.getSubnodeNameHash.returns(accountNameHash);

      const pubDataDeposit = encodePackPubData(PubDataTypeMap[PubDataType.Deposit], [
        PubDataType.Deposit,
        0,
        0,
        10,
        accountNameHash,
      ]);

      await zkBNB.depositBNB('accountNameHash', { value: 10 });
      const commitBlock3: CommitBlockInfo = {
        newStateRoot,
        publicData: ethers.utils.hexConcat([pubDataDeposit]),
        timestamp: Date.now(),
        publicDataOffsets: [0],
        blockNumber: 3,
        blockSize: 1,
      };
      lastBlock = await zkBNB.getLastCommittedBlockData(storedBlockInfo, commitBlock3);
      await zkBNB.commitBlocks(storedBlockInfo, [commitBlock3]);

      storedBlockInfo = {
        blockSize: lastBlock.blockSize,
        blockNumber: lastBlock.blockNumber,
        priorityOperations: lastBlock.priorityOperations,
        pendingOnchainOperationsHash: lastBlock.pendingOnchainOperationsHash,
        timestamp: lastBlock.timestamp,
        stateRoot: lastBlock.stateRoot,
        commitment: lastBlock.commitment,
      };
      verifyAndExecuteBlockInfos.push({
        blockHeader: storedBlockInfo,
        pendingOnchainOpsPubData: [commitBlock3.publicData],
      });

      const proofs = new Array(24).fill(10);
      await expect(zkBNB.verifyAndExecuteBlocks(verifyAndExecuteBlockInfos, proofs)).to.revertedWith('l');
    });
  });
});
