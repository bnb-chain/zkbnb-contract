// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../interfaces/INFTFactory.sol";
import "../AdditionalZkBNB.sol";

contract AdditionalZkBNBTest is AdditionalZkBNB {
  function getLastCommittedBlockData(
    StoredBlockInfo memory _previousBlock,
    CommitBlockInfo memory _newBlock
  ) external view returns (StoredBlockInfo memory storedNewBlock) {
    return commitOneBlock(_previousBlock, _newBlock);
  }
}
