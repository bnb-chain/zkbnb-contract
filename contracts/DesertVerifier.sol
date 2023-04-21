// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

contract DesertVerifier {
  struct AssetExitData {
    uint16 assetId;
    uint128 amount;
    uint offerCanceledOrFinalized;
  }

  struct AccountExitData {
    uint32 accountId;
    address l1Address;
    bytes32 pubKeyX;
    bytes32 pubKeyY;
    uint nonce;
    uint collectionNonce;
  }

  struct NftExitData {
    uint40 nftIndex;
    uint ownerAccountIndex;
    uint32 creatorAccountIndex;
    uint16 creatorTreasuryRate;
    uint16 collectionId;
    bytes16 nftContentHash1;
    bytes16 nftContentHash2;
    uint8 nftContentType;
  }

  /// @notice verify ownership of assets
  function verifyExitProofBalance(
    uint256 stateRoot,
    uint256 nftRoot,
    AssetExitData calldata assetData,
    AccountExitData calldata accountData,
    uint256[] memory _proofs
  ) external view returns (bool) {
    // TODO
    return false;
  }

  /// @notice verify ownership of nfts
  function verifyExitNftProof(
    uint256 stateRoot,
    uint256 assetRoot,
    AccountExitData memory accountData,
    NftExitData[] memory exitNfts,
    uint256[] memory _proofs
  ) public view returns (bool) {
    // TODO
    return false;
  }
}
