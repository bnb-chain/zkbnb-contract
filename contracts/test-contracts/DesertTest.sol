// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../DesertVerifier.sol";

contract DesertVerifierTest is DesertVerifier {
  constructor(address _poseidonT3, address _poseidonT7) DesertVerifier(_poseidonT3, _poseidonT7) {}

  function testGetAssetRoot(
    uint16 assetId,
    uint128 amount,
    uint256 offerCanceledOrFinalized,
    uint256[16] memory assetMerkleProof
  ) external view returns (uint256) {
    return getAssetRoot(assetId, amount, offerCanceledOrFinalized, assetMerkleProof);
  }

  function testGetAccountRoot(
    uint32 accountId,
    address l1Address,
    bytes32 pubKeyX,
    bytes32 pubKeyY,
    uint256 nonce,
    uint256 collectionNonce,
    uint256 assetRoot,
    uint256[32] memory accountMerkleProof
  ) external view returns (uint256) {
    return
      getAccountRoot(
        accountId,
        uint256(uint160(l1Address)),
        uint256(pubKeyX),
        uint256(pubKeyY),
        nonce,
        collectionNonce,
        assetRoot,
        accountMerkleProof
      );
  }

  function testGetNftRoot(
    uint40 nftIndex,
    uint8 _nftContentType,
    uint256 ownerAccountIndex,
    uint32 creatorAccountIndex,
    bytes16 nftContentHash1,
    bytes16 nftContentHash2,
    uint16 creatorTreasuryRate,
    uint16 collectionId,
    uint256[40] memory nftMerkleProof
  ) external view returns (uint256) {
    return
      getNftRoot(
        nftIndex,
        creatorAccountIndex,
        ownerAccountIndex,
        uint256(uint128(nftContentHash1)),
        uint256(uint128(nftContentHash2)),
        creatorTreasuryRate,
        collectionId,
        nftMerkleProof
      );
  }
}
