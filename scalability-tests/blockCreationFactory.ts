import { Bytes, Contract } from 'ethers';
import { ethers } from 'hardhat';
import {
  CommitBlockInfo,
  EMPTY_STRING_KECCAK,
  PubDataType,
  PubDataTypeMap,
  StoredBlockInfo,
  encodePackPubData,
  padEndBytes121,
} from '../test/util';
import { expect } from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

/**
 * Block creation factory is responsible for creating mock txs and rolling them into
 * blocks of necessary sizes
 *
 * Usage: Use start to mark start position for the block and finish rollup rolles all the txs into a block
 *
 * Example:
 * startBlock()
 * createZNSAccountNameTx()
 * createDepositTx()
 * createDepositTx()
 * finishAndCommitBlock()
 *
 */
export class BlockCreationFactory {
  zkBNB: Contract;
  additionalZkBNB: Contract;
  owner: SignerWithAddress;
  private lastCommittedBlock: StoredBlockInfo;
  private currBlocks: CommitBlockInfo[];
  private pubDatas: Bytes[];
  private offsets: any[]; //Stores offset of pubdatas in the above array
  private nextOffsetIndex: number;

  constructor(zkBNB: Contract, additionalZkBNB: Contract, owner: SignerWithAddress) {
    this.zkBNB = zkBNB;
    this.additionalZkBNB = additionalZkBNB;
    this.owner = owner;
    //Genesis block
    this.lastCommittedBlock = {
      blockSize: 0,
      blockNumber: 0,
      priorityOperations: 0,
      pendingOnchainOperationsHash: EMPTY_STRING_KECCAK,
      timestamp: 0,
      stateRoot: ethers.utils.formatBytes32String('genesisStateRoot'),
      commitment: ethers.utils.formatBytes32String(''),
    };
    this.currBlocks = [];
    this.pubDatas = [];
    this.offsets = [];
    this.nextOffsetIndex = 0;
  }

  resetBlock() {
    this.pubDatas = [];
    this.offsets = [];
    this.nextOffsetIndex = 0;
  }

  //Returns the txs count in this block
  markBlockFinish(): number {
    if (this.pubDatas.length == 0) {
      console.log('No txs in the block. Abort block makeup');
      process.exit(1);
    }
    const newStateRoot = ethers.utils.formatBytes32String('newStateRoot');
    const blockSize = this.offsets.length;
    const commitBlock: CommitBlockInfo = {
      newStateRoot,
      publicData: padEndBytes121(ethers.utils.hexConcat(this.pubDatas)),
      timestamp: Date.now(),
      publicDataOffsets: this.offsets,
      blockNumber: this.lastCommittedBlock.blockNumber + this.currBlocks.length + 1,
      blockSize,
    };
    this.currBlocks.push(commitBlock);
    //Update the last recorded block

    this.resetBlock();
    return blockSize;
  }

  async commitAndFlushAllBlocks() {
    if (this.pubDatas.length != 0) {
      console.error('Please use markBlockFinish() before committing the block');
      process.exit(1);
    }
    const preComputeLastStoredBlockWithCurrBlocks = async (
      lastStoredBlock: StoredBlockInfo,
      currBlocks: CommitBlockInfo[],
    ): Promise<StoredBlockInfo> => {
      for (const curr in currBlocks) {
        lastStoredBlock = await this.additionalZkBNB
          .attach(this.zkBNB.address)
          .getLastCommittedBlockData(lastStoredBlock, currBlocks[curr]);
      }
      return lastStoredBlock;
    };
    //Use the test contract to retrieve how the last stored block will look like after batch commit
    const lastCommittedBlockStored = await preComputeLastStoredBlockWithCurrBlocks(
      this.lastCommittedBlock,
      this.currBlocks,
    );

    await expect(this.zkBNB.commitBlocks(this.lastCommittedBlock, this.currBlocks))
      .to.emit(this.zkBNB, 'BlockCommit')
      .withArgs(this.currBlocks[this.currBlocks.length - 1].blockNumber);

    //Set last block to the last among all the committed blocks
    this.lastCommittedBlock = {
      blockSize: lastCommittedBlockStored.blockSize,
      blockNumber: lastCommittedBlockStored.blockNumber,
      priorityOperations: lastCommittedBlockStored.priorityOperations,
      pendingOnchainOperationsHash: lastCommittedBlockStored.pendingOnchainOperationsHash,
      timestamp: lastCommittedBlockStored.timestamp,
      stateRoot: lastCommittedBlockStored.stateRoot,
      commitment: lastCommittedBlockStored.commitment,
    };
    //Clear all blocks locally
    this.currBlocks = [];
    this.resetBlock();
  }

  async createZNSAccountNameTx() {
    const pubKeyX = ethers.utils.formatBytes32String('pubKeyX');
    const pubKeyY = ethers.utils.formatBytes32String('pubKeyY');

    //Create and listen to pub data
    const tx = await this.zkBNB.registerZNS('accountNameHash', this.owner.address, pubKeyX, pubKeyY);
    const receipt = await tx.wait();
    const event = receipt.events.find((event) => {
      return event.event === 'NewPriorityRequest';
    });
    const pubDataRegisterZNS: Bytes = event.args[3];
    this.appendPubData(pubDataRegisterZNS);
  }
  async createDepositBEP20Tx(mockERC20: Contract) {
    const accountNameHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('accountNameHash'));

    const pubDataDeposit20 = encodePackPubData(PubDataTypeMap[PubDataType.Deposit], [
      PubDataType.Deposit,
      0,
      3,
      10,
      accountNameHash,
    ]);
    await this.zkBNB.depositBEP20(mockERC20.address, 10, 'accountNameHash');

    this.appendPubData(pubDataDeposit20);
  }

  async createDepositBNBTx() {
    const accountNameHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('accountNameHash'));

    const pubDataDeposit = encodePackPubData(PubDataTypeMap[PubDataType.Deposit], [
      PubDataType.Deposit,
      0,
      0,
      10,
      accountNameHash,
    ]);
    await this.zkBNB.depositBNB('accountNameHash', { value: 10 });

    this.appendPubData(pubDataDeposit);
  }

  //Add pubdata to the ongoing block
  private appendPubData(newPubData) {
    this.offsets.push(this.nextOffsetIndex);
    this.pubDatas.push(newPubData);
    this.nextOffsetIndex += newPubData.length / 2 - 1; //byte-len = hex/2 and -1 for "0x"
  }
}
