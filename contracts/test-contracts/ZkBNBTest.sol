// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../lib/TxTypes.sol";
import "../interfaces/INFTFactory.sol";
import "../ZkBNB.sol";
import "../Storage.sol";
import "../Config.sol";

contract ZkBNBTest is ZkBNB {
  /// @notice Same as fallback but called when calldata is empty
  receive() external payable {
    _fallback();
  }

  function _fallback() internal {
    address _target = address(additionalZkBNB);
    assembly {
      // The pointer to the free memory slot
      let ptr := mload(0x40)
      // Copy function signature and arguments from calldata at zero position into memory at pointer position
      calldatacopy(ptr, 0x0, calldatasize())
      // Delegatecall method of the implementation contract, returns 0 on error
      let result := delegatecall(gas(), _target, ptr, calldatasize(), 0x0, 0)
      // Get the size of the last return data
      let size := returndatasize()
      // Copy the size length of bytes from return data at zero position to pointer position
      returndatacopy(ptr, 0x0, size)
      // Depending on result value
      switch result
      case 0 {
        // End execution and revert state changes
        revert(ptr, size)
      }
      default {
        // Return data with length of size at pointers position
        return(ptr, size)
      }
    }
  }

  /// @notice Will run when no functions matches call data
  fallback() external payable {
    _fallback();
  }

  function getMintedL2NftInfo(bytes32 nftKey) external view returns (L2NftInfo memory) {
    return mintedNfts[nftKey];
  }

  function getPriorityRequest(uint64 priorityRequestId) external view returns (PriorityTx memory) {
    return priorityRequests[priorityRequestId];
  }

  function getPendingWithdrawnNFT(uint40 nftIndex) external view returns (TxTypes.WithdrawNft memory) {
    return pendingWithdrawnNFTs[nftIndex];
  }

  function testWithdrawOrStoreNFT(TxTypes.WithdrawNft memory op) external returns (bool) {
    return withdrawOrStoreNFT(op, WITHDRAWAL_NFT_GAS_LIMIT);
  }

  function testWithdrawOrStore(uint16 _assetId, address _recipient, uint128 _amount) external {
    return withdrawOrStore(_assetId, _recipient, _amount);
  }

  function testIncreasePendingBalance(uint16 _assetId, address _recipient, uint128 _amount) external {
    bytes22 packedBalanceKey = packAddressAndAssetId(_recipient, _assetId);
    increaseBalanceToWithdraw(packedBalanceKey, _amount);
  }

  function getLastCommittedBlockData(
    StoredBlockInfo memory _previousBlock,
    CommitBlockInfo memory _newBlock
  ) external view returns (StoredBlockInfo memory storedNewBlock) {
    return commitOneBlock(_previousBlock, _newBlock);
  }

  function mintNFT(
    address defaultNFTFactory,
    address _toAddress,
    uint8 _nftContentType,
    uint256 _nftTokenId,
    bytes32 _nftContentHash
  ) external {
    return INFTFactory(defaultNFTFactory).mintFromZkBNB(_toAddress, _nftContentType, _nftTokenId, _nftContentHash);
  }
}
