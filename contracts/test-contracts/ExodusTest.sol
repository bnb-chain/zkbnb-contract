// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../ExodusVerifier.sol";

contract ExodusVerifierTest is ExodusVerifier {
  constructor(
    address _poseidonT3,
    address _poseidonT6,
    address _poseidonT7
  ) ExodusVerifier(_poseidonT3, _poseidonT6, _poseidonT7) {}

  function testGetAssetRoot(
    uint256 assetId,
    uint256 amount,
    uint256 offerCanceledOrFinalized,
    uint256[16] memory assetMerkleProof
  ) external returns (uint256) {
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
  ) external returns (uint256) {
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
}
