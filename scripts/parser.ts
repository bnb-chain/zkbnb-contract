import { ethers } from 'hardhat';

import zkBNB from '../abi/ZkBNB.json';
import { CommitBlockInfo, StoredBlockInfo, VerifyAndExecuteBlockInfo } from '../test/util';

interface CommitBlocks {
  _lastCommittedBlockData: StoredBlockInfo;
  _newBlocksData: CommitBlockInfo[];
}

interface VerifyAndExecuteBlocks {
  _blocks: VerifyAndExecuteBlockInfo;
  _proofs: number[];
}

interface RevertBlocks {
  _blocksToRevert: StoredBlockInfo[];
}

async function main() {
  const txHash = '0xfaf8b3379123a7cdbf39f1952e2b7808e7a0f4ea000077786af29136f34cd19e';
  // const txHash = '0x1752bc49ba2d684e578cb09b0edee11458839198d60cfddf3c22c22de67f2e23';
  // const txHash = '0xe2d178a124a072507429caba335847933b02d1502d9df77a7c0d7e36a1a56988';
  const functionName = 'commitBlocks';
  // const functionName = 'verifyAndExecuteBlocks';
  // const functionName = 'revertBlocks';

  const tx = await ethers.provider.getTransaction(txHash);

  const iZkBNB = new ethers.utils.Interface(zkBNB);

  if (functionName == 'verifyAndExecuteBlocks') {
    const parsed: VerifyAndExecuteBlocks = iZkBNB.decodeFunctionData(functionName, tx.data);
    console.log(parsed['_blocks']);
  } else {
    const parsed: CommitBlocks | RevertBlocks = iZkBNB.decodeFunctionData(functionName, tx.data);
    console.log(parsed);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
