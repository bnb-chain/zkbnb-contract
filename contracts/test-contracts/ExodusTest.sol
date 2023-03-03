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
    bytes32[16] memory assetMerkleProof
  ) external view returns (uint256) {
    return getAssetRoot(assetId, amount, offerCanceledOrFinalized, assetMerkleProof);
  }
}
