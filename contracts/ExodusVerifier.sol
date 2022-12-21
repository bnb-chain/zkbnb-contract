// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./interfaces/IPoseidon.sol";

contract ExodusVerifier {
  IPoseidon poseidon;

  struct ExitData {
    uint32 assetID;
    uint32 accountId;
    uint64 nftIndex;
    uint amount;
    uint offerCanceledOrFinalized;
    uint accountNameHash;
    uint pubKeyX;
    uint pubKeyY;
    uint nonce;
    uint collectionNonce;
    uint creatorAccountIndex;
    uint ownerAccountIndex;
    uint nftContentHash;
    uint creatorTreasuryRate;
    uint collectionId;
  }

  function verifyExitProof(
    uint256 stateRoot,
    ExitData memory exitData,
    uint256[16] calldata assetMerkleProof,
    uint256[32] calldata accountMerkleProof,
    uint256[40] calldata nftMerkleProof
  ) public returns (bool) {
    uint256 assetRoot = getAssetRoot(
      exitData.assetID,
      exitData.amount,
      exitData.offerCanceledOrFinalized,
      assetMerkleProof
    );
    uint256 accountRoot = getAccountRoot(
      exitData.accountId,
      exitData.accountNameHash,
      exitData.pubKeyX,
      exitData.pubKeyY,
      exitData.nonce,
      exitData.collectionNonce,
      assetRoot,
      accountMerkleProof
    );
    uint256 nftRoot = getNftRoot(
      exitData.nftIndex,
      exitData.creatorAccountIndex,
      exitData.ownerAccountIndex,
      exitData.nftContentHash,
      exitData.creatorTreasuryRate,
      exitData.collectionId,
      nftMerkleProof
    );

    return (hashNode(accountRoot, nftRoot) == stateRoot);
  }

  function getAssetRoot(
    uint256 assetId,
    uint256 amount,
    uint256 offerCanceledOrFinalized,
    uint256[16] calldata assetMerkleProof
  ) private returns (uint256) {
    uint256 assetLeafHash = hashNode(amount, offerCanceledOrFinalized);
    uint256 rootHash = assetLeafHash;

    for (uint i = 0; i < 16; i++) {
      if (assetId % 2 == 0) {
        rootHash = hashNode(rootHash, assetMerkleProof[i]);
      } else {
        rootHash = hashNode(assetMerkleProof[i], rootHash);
      }
    }
    return rootHash;
  }

  function getAccountRoot(
    uint32 accountId,
    uint256 accountNameHash,
    uint256 pubKeyX,
    uint256 pubKeyY,
    uint256 nonce,
    uint256 collectionNonce,
    uint256 assetRoot,
    uint256[32] calldata accountMerkleProof
  ) private returns (uint256) {
    uint256[6] memory inputs;
    inputs[0] = accountNameHash;
    inputs[1] = pubKeyX;
    inputs[2] = pubKeyY;
    inputs[3] = nonce;
    inputs[4] = collectionNonce;
    inputs[5] = assetRoot;
    uint256 accountLeafHash = poseidon.poseidonInputs6(inputs);
    uint256 rootHash = accountLeafHash;

    for (uint i = 0; i < 32; i++) {
      if (accountId % 2 == 0) {
        rootHash = hashNode(rootHash, accountMerkleProof[i]);
      } else {
        rootHash = hashNode(accountMerkleProof[i], rootHash);
      }
    }
    return rootHash;
  }

  function getNftRoot(
    uint64 nftIndex,
    uint256 creatorAccountIndex,
    uint256 ownerAccountIndex,
    uint256 nftContentHash,
    uint256 creatorTreasuryRate,
    uint256 collectionId,
    uint256[40] calldata nftMerkleProof
  ) private returns (uint256) {
    uint256[5] memory inputs;
    inputs[0] = creatorAccountIndex;
    inputs[1] = ownerAccountIndex;
    inputs[2] = nftContentHash;
    inputs[3] = creatorTreasuryRate;
    inputs[4] = collectionId;
    uint256 nftLeafHash = poseidon.poseidonInputs5(inputs);
    uint256 rootHash = nftLeafHash;

    for (uint i = 0; i < 32; i++) {
      if (nftIndex % 2 == 0) {
        rootHash = hashNode(rootHash, nftMerkleProof[i]);
      } else {
        rootHash = hashNode(nftMerkleProof[i], rootHash);
      }
    }
    return rootHash;
  }

  function hashNode(uint256 left, uint256 right) internal view returns (uint256) {
    uint256[2] memory inputs;
    inputs[0] = left;
    inputs[1] = right;
    return poseidon.poseidonInputs2(inputs);
  }
}
