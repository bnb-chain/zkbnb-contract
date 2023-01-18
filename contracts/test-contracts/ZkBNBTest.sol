// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../lib/TxTypes.sol";
import "../interfaces/INFTFactory.sol";
import "../ZkBNB.sol";
import "../Storage.sol";

contract ZkBNBTest is ZkBNB {
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

  function testSetDefaultNFTFactory(INFTFactory _factory) external {
    defaultNFTFactory = address(_factory);
  }

  function testSetMinMaxIntervalsForNameRegistration(uint min, uint max) external {
    minCommitmentAge = min;
    maxCommitmentAge = max;
  }

  function mintNFT(
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
