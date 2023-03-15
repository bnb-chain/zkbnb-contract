import { ethers } from 'hardhat';
import chai, { expect } from 'chai';
import { smock } from '@defi-wonderland/smock';

import {
  CommitBlockInfo,
  EMPTY_STRING_KECCAK,
  OnchainOperationData,
  PubDataType,
  PubDataTypeMap,
  StoredBlockInfo,
  VerifyAndExecuteBlockInfo,
  encodePackPubData,
  encodePubData,
  getChangePubkeyMessage,
  hashStoredBlockInfo,
  padEndBytes121,
} from './util';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { zeroPad } from '@ethersproject/bytes/src.ts';

chai.use(smock.matchers);

describe('ZkBNB', function () {
  let mockGovernance;
  let mockZkBNBVerifier;
  let mockERC20;
  let mockNftFactory;
  let zkBNB;
  let additionalZkBNB;
  let owner: SignerWithAddress,
    addr1: SignerWithAddress,
    addr2: SignerWithAddress,
    addr3: SignerWithAddress,
    addr4: SignerWithAddress;
  const account = '0xB4fdA33E65656F9f485438ABd9012eD04a31E006';

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
    mockERC20 = await smock.fake('ERC20');

    mockNftFactory = await smock.fake('ZkBNBNFTFactory');

    const Utils = await ethers.getContractFactory('Utils');
    utils = await Utils.deploy();
    await utils.deployed();

    const AdditionalZkBNB = await ethers.getContractFactory('AdditionalZkBNBTest');
    additionalZkBNB = await AdditionalZkBNB.deploy(ethers.constants.AddressZero);
    await additionalZkBNB.deployed();

    const ZkBNB = await ethers.getContractFactory('ZkBNBTest', {
      libraries: {
        Utils: utils.address,
      },
    });
    zkBNB = await ZkBNB.deploy();
    await zkBNB.deployed();

    const initParams = ethers.utils.defaultAbiCoder.encode(
      ['address', 'address', 'address', 'bytes32'],
      [mockGovernance.address, mockZkBNBVerifier.address, additionalZkBNB.address, genesisStateRoot],
    );
    await zkBNB.initialize(initParams);

    // mock functions
    mockGovernance.getNFTFactory.returns(mockNftFactory.address);
    mockNftFactory.mintFromZkBNB.returns();
  });

  describe('commit blocks', function () {
    const ASSET_ID = 3;

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
          account,
          ASSET_ID,
          10,
        ]);

        pubDataDeposit20 = encodePackPubData(PubDataTypeMap[PubDataType.Deposit], [
          PubDataType.Deposit,
          0,
          account,
          ASSET_ID,
          10,
        ]);
      });

      it('should revert if use unsupported type', async () => {
        const pubData = encodePackPubData(PubDataTypeMap[PubDataType.Deposit], [20, 0, account, 0, 10]);

        const onchainOperations: OnchainOperationData[] = [
          { ethWitness: ethers.utils.formatBytes32String(''), publicDataOffset: 0 },
          { ethWitness: ethers.utils.formatBytes32String(''), publicDataOffset: 121 },
        ];

        const commitBlock: CommitBlockInfo = {
          newStateRoot,
          publicData: ethers.utils.hexConcat([pubData]),
          timestamp: Date.now(),
          onchainOperations,
          blockNumber: 1,
          blockSize: 2,
        };
        await expect(zkBNB.commitBlocks(genesisBlock, [commitBlock])).to.be.reverted;
      });

      it('should revert if user is not operating on the chain', async () => {
        const onchainOperations: OnchainOperationData[] = [
          { ethWitness: ethers.utils.formatBytes32String(''), publicDataOffset: 0 },
          { ethWitness: ethers.utils.formatBytes32String(''), publicDataOffset: 121 },
        ];

        const commitBlock: CommitBlockInfo = {
          newStateRoot,
          publicData: ethers.utils.hexConcat([pubDataDeposit, pubDataDeposit20]),
          timestamp: Date.now(),
          onchainOperations,
          blockNumber: 1,
          blockSize: 2,
        };
        await expect(zkBNB.commitBlocks(genesisBlock, [commitBlock])).to.be.reverted;
      });

      it('should revert if block number is wrong', async () => {
        await zkBNB.depositBNB(account, { value: 10 });

        mockERC20.transferFrom.returns(true);
        mockGovernance.validateAssetAddress.returns(ASSET_ID);
        mockGovernance.pausedAssets.returns(false);
        mockERC20.balanceOf.returnsAtCall(0, 100);
        mockERC20.balanceOf.returnsAtCall(1, 110);

        await zkBNB.depositBEP20(mockERC20.address, 10, account);

        const onchainOperations: OnchainOperationData[] = [
          { ethWitness: ethers.utils.formatBytes32String(''), publicDataOffset: 0 },
          { ethWitness: ethers.utils.formatBytes32String(''), publicDataOffset: 121 },
        ];

        const commitBlock: CommitBlockInfo = {
          newStateRoot,
          publicData: ethers.utils.hexConcat([pubDataDeposit, pubDataDeposit20]),
          timestamp: Date.now(),
          onchainOperations,
          blockNumber: 2,
          blockSize: 3,
        };
        await expect(zkBNB.commitBlocks(genesisBlock, [commitBlock])).to.be.reverted;
      });

      it('should can commit changePubKey operation', async () => {
        const changePubKey = {
          txType: PubDataType.ChangePubKey,
          accountIndex: 0,
          pubkeyX: ethers.utils.hexlify(ethers.utils.randomBytes(32)),
          pubkeyY: ethers.utils.hexlify(ethers.utils.randomBytes(32)),
          owner: owner.address,
          nonce: 0,
        };
        const message = getChangePubkeyMessage(
          changePubKey.pubkeyX,
          changePubKey.pubkeyY,
          changePubKey.nonce,
          changePubKey.accountIndex,
        );

        const signature = await owner.signMessage(message);
        const address = ethers.utils.verifyMessage(message, signature);
        expect(address).equal(owner.address);
        const version = new Uint8Array([0]); // current version is zero
        const signatureBytes = ethers.utils.arrayify(signature);
        const ethWitness = ethers.utils.hexlify(ethers.utils.concat([version, signatureBytes]));

        const pubData = encodePubData(PubDataTypeMap[PubDataType.ChangePubKey], [
          PubDataType.ChangePubKey,
          changePubKey.accountIndex,
          changePubKey.pubkeyX,
          changePubKey.pubkeyY,
          changePubKey.owner,
          changePubKey.nonce,
        ]);

        const onchainOperations: OnchainOperationData[] = [{ ethWitness, publicDataOffset: 0 }];

        const commitBlock: CommitBlockInfo = {
          newStateRoot,
          publicData: ethers.utils.hexlify(padEndBytes121(pubData)),
          timestamp: Date.now(),
          onchainOperations,
          blockNumber: 1,
          blockSize: 2,
        };
        onchainOperations[0].ethWitness = '0x';
        await expect(zkBNB.commitBlocks(genesisBlock, [commitBlock])).to.be.revertedWith(
          'signature should not be empty',
        );
        onchainOperations[0].ethWitness = ethers.utils.hexlify(ethers.utils.randomBytes(66));
        await expect(zkBNB.commitBlocks(genesisBlock, [commitBlock])).to.be.revertedWith('D');
        onchainOperations[0].ethWitness = ethWitness;
        await expect(zkBNB.commitBlocks(genesisBlock, [commitBlock]))
          .to.emit(zkBNB, 'BlockCommit')
          .withArgs(1);
      });

      it('should can commit deposit operation', async () => {
        const bnbTx = await zkBNB.depositBNB(account, { value: 10 });
        const bnbReceipt = await bnbTx.wait();
        const bnbEvent = bnbReceipt.events.find((event) => {
          return event.event === 'NewPriorityRequest';
        });
        const bnbPubData = bnbEvent.args[3];

        mockERC20.transferFrom.returns(true);
        mockGovernance.validateAssetAddress.returns(ASSET_ID);
        mockGovernance.pausedAssets.returns(false);
        mockERC20.balanceOf.returnsAtCall(0, 100);
        mockERC20.balanceOf.returnsAtCall(1, 110);

        const bep20Tx = await zkBNB.depositBEP20(mockERC20.address, 10, account);
        const bep20Receipt = await bep20Tx.wait();
        const bep20Event = bep20Receipt.events.find((event) => {
          return event.event === 'NewPriorityRequest';
        });
        const bep20PubData = bep20Event.args[3];

        const onchainOperations: OnchainOperationData[] = [
          { ethWitness: ethers.utils.formatBytes32String(''), publicDataOffset: 0 },
          { ethWitness: ethers.utils.formatBytes32String(''), publicDataOffset: 121 },
        ];

        const commitBlock: CommitBlockInfo = {
          newStateRoot,
          publicData: ethers.utils.hexConcat([padEndBytes121(bnbPubData), padEndBytes121(bep20PubData)]),
          timestamp: Date.now(),
          onchainOperations,
          blockNumber: 1,
          blockSize: 2,
        };
        await expect(zkBNB.commitBlocks(genesisBlock, [commitBlock]))
          .to.emit(zkBNB, 'BlockCommit')
          .withArgs(1);
      });

      it('should can commit fullExit operation', async () => {
        // mock user request full exit, and get pubData

        const tx = await zkBNB.requestFullExit(0, ethers.constants.AddressZero);
        const receipt = await tx.wait();

        const event = receipt.events.find((event) => {
          return event.event === 'NewPriorityRequest';
        });
        const pubDataFullExit = event.args[3];

        const onchainOperations: OnchainOperationData[] = [
          { ethWitness: ethers.utils.formatBytes32String(''), publicDataOffset: 0 },
        ];
        const commitBlock: CommitBlockInfo = {
          newStateRoot,
          publicData: ethers.utils.hexConcat([padEndBytes121(pubDataFullExit)]),
          timestamp: Date.now(),
          onchainOperations,
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
          const withdrawOp = {
            txType: 11, // WithdrawNft
            accountIndex: 1,
            creatorAccountIndex: 0,
            creatorTreasuryRate: 5,
            nftIndex: nftL1TokenId,
            collectionId: 0,
            gasFeeAccountIndex: 1,
            gasFeeAssetId: 0, //BNB
            gasFeeAssetAmount: 666,
            toAddress: owner.address,
            nftContentHash: mockHash,
            creatorAddress: account,
            nftContentType: 0,
          };

          await zkBNB.testWithdrawOrStoreNFT(withdrawOp);
        });

        it.skip('should can commit deposit NFT operation', async () => {
          mockNftFactory.ownerOf.returns(zkBNB.address);

          const tx = await zkBNB.depositNft(account, mockNftFactory.address, nftL1TokenId);

          const receipt = await tx.wait();
          const event = receipt.events.find((event) => {
            return event.event === 'NewPriorityRequest';
          });
          const pubDataDepositNft = event.args[3];

          const onchainOperations: OnchainOperationData[] = [
            { ethWitness: ethers.utils.formatBytes32String(''), publicDataOffset: 0 },
            { ethWitness: ethers.utils.formatBytes32String(''), publicDataOffset: 121 },
          ];
          const commitBlock: CommitBlockInfo = {
            newStateRoot,
            publicData: ethers.utils.hexConcat([padEndBytes121(pubDataDepositNft)]),
            timestamp: Date.now(),
            onchainOperations,
            blockNumber: 1,
            blockSize: 1,
          };
          await expect(zkBNB.commitBlocks(genesisBlock, [commitBlock]))
            .to.emit(zkBNB, 'BlockCommit')
            .withArgs(1);
        });

        it('should can commit fullExitNFT operation', async () => {
          mockNftFactory.ownerOf.returns(zkBNB.address);

          const tx = await zkBNB.requestFullExitNft(0, nftL1TokenId);

          const receipt = await tx.wait();
          const event = receipt.events.find((event) => {
            return event.event === 'NewPriorityRequest';
          });
          const pubDataDepositNft = event.args[3];

          const onchainOperations: OnchainOperationData[] = [
            { ethWitness: ethers.utils.formatBytes32String(''), publicDataOffset: 0 },
          ];
          const commitBlock: CommitBlockInfo = {
            newStateRoot,
            publicData: ethers.utils.hexConcat([padEndBytes121(pubDataDepositNft)]),
            timestamp: Date.now(),
            onchainOperations,
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
      mockNftFactory.ownerOf.returns(zkBNB.address);

      // Pre-submit a block for every case
      // commit block #1 fullExit nft;
      let tx = await zkBNB.requestFullExitNft(0, nftL1TokenId);
      let receipt = await tx.wait();
      let event = receipt.events.find((event) => {
        return event.event === 'NewPriorityRequest';
      });

      const pubData = event.args[3];

      const onchainOperations: OnchainOperationData[] = [
        { ethWitness: ethers.utils.formatBytes32String(''), publicDataOffset: 0 },
      ];
      const commitBlock: CommitBlockInfo = {
        newStateRoot,
        publicData: ethers.utils.hexConcat([padEndBytes121(pubData)]),
        timestamp: Date.now(),
        onchainOperations,
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
      tx = await zkBNB.requestFullExit(0, ethers.constants.AddressZero);
      receipt = await tx.wait();

      event = receipt.events.find((event) => {
        return event.event === 'NewPriorityRequest';
      });
      const pubDataFullExit = event.args[3];
      const commitBlock2: CommitBlockInfo = {
        newStateRoot,
        publicData: ethers.utils.hexConcat([padEndBytes121(pubDataFullExit)]),
        timestamp: Date.now(),
        onchainOperations,
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

      const pubDataDeposit = encodePackPubData(PubDataTypeMap[PubDataType.Deposit], [
        PubDataType.Deposit,
        0,
        account,
        0,
        10,
      ]);

      await zkBNB.depositBNB(account, { value: 10 });
      const onchainOperations: OnchainOperationData[] = [
        { ethWitness: ethers.utils.formatBytes32String(''), publicDataOffset: 0 },
      ];
      const commitBlock3: CommitBlockInfo = {
        newStateRoot,
        publicData: ethers.utils.hexConcat([pubDataDeposit]),
        timestamp: Date.now(),
        onchainOperations,
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
