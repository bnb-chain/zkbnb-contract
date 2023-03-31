// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../DesertVerifier.sol";

contract DesertVerifierTest is DesertVerifier {
  constructor(
    address _poseidonT3,
    address _poseidonT6,
    address _poseidonT7
  ) DesertVerifier(_poseidonT3, _poseidonT6, _poseidonT7) {}

  function testGetAssetRoot(
    uint16 assetId,
    uint256 amount,
    uint256 offerCanceledOrFinalized,
    uint256[16] memory assetMerkleProof
  ) external view returns (uint256) {
    return getAssetRoot(assetId, amount, offerCanceledOrFinalized, assetMerkleProof);
  }

  function testGetAccountRoot(
    uint32 accountId,
    uint256 accountNameHash,
    uint256 pubKeyX,
    uint256 pubKeyY,
    uint256 nonce,
    uint256 collectionNonce,
    uint256 assetRoot,
    uint256[32] memory accountMerkleProof
  ) external view returns (uint256) {
    return
      getAccountRoot(
        accountId,
        accountNameHash,
        pubKeyX,
        pubKeyY,
        nonce,
        collectionNonce,
        assetRoot,
        accountMerkleProof
      );
  }

  function testGetNftRoot(
    uint40 nftIndex,
    uint256 creatorAccountIndex,
    uint256 ownerAccountIndex,
    uint256 nftContentHash,
    uint256 creatorTreasuryRate,
    uint256 collectionId,
    uint256 nftContentType,
    uint256[40] memory nftMerkleProof
  ) external view returns (uint256) {
    return
      getNftRoot(
        nftIndex,
        creatorAccountIndex,
        ownerAccountIndex,
        nftContentHash,
        creatorTreasuryRate,
        collectionId,
        nftContentType,
        nftMerkleProof
      );
  }
}
