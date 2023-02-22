// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../lib/TxTypes.sol";
import "../interfaces/INFTFactory.sol";
import "../ZkBNB.sol";
import "../Storage.sol";

contract ZkBNBTest is ZkBNB {
  /// @notice Same as fallback but called when calldata is empty
  function getMintedL2NftInfo(bytes32 nftKey) external view returns (L2NftInfo memory) {
    return mintedNfts[nftKey];
  }

  function getPriorityRequest(uint64 priorityRequestId) external view returns (PriorityTx memory) {
    return priorityRequests[priorityRequestId];
  }

  function getPendingWithdrawnNFT(uint40 nftIndex) external view returns (TxTypes.WithdrawNft memory) {
    return pendingWithdrawnNFTs[nftIndex];
  }

  function testWithdrawOrStoreNFT(TxTypes.WithdrawNft memory op) external {
    return withdrawOrStoreNFT(op);
  }

  function getLastCommittedBlockData(
    StoredBlockInfo memory _previousBlock,
    CommitBlockInfo memory _newBlock
  ) external view returns (StoredBlockInfo memory storedNewBlock) {
    return commitOneBlock(_previousBlock, _newBlock);
  }

  function mintNFT(
    address defaultNFTFactory,
    address _creatorAddress,
    address _toAddress,
    uint256 _nftTokenId,
    bytes32 _nftContentHash,
    bytes memory _extraData
  ) external {
    return
      INFTFactory(defaultNFTFactory).mintFromZkBNB(
        _creatorAddress,
        _toAddress,
        _nftTokenId,
        _nftContentHash,
        _extraData
      );
  }
}
