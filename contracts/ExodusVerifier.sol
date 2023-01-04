// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./interfaces/IPoseidon.sol";

contract ExodusVerifier {
  IPoseidonT3 poseidonT3;
  IPoseidonT6 poseidonT6;
  IPoseidonT7 poseidonT7;

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

  constructor(address _poseidonT3, address _poseidonT6, address _poseidonT7) {
    poseidonT3 = IPoseidonT3(_poseidonT3);
    poseidonT6 = IPoseidonT6(_poseidonT6);
    poseidonT7 = IPoseidonT7(_poseidonT7);
  }

  function verifyExitProof(
    uint256 stateRoot,
    ExitData calldata exitData,
    uint256[15] memory assetMerkleProof,
    uint256[31] memory accountMerkleProof,
    uint256[39] memory nftMerkleProof
  ) public view returns (bool) {
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
    uint256[15] memory assetMerkleProof
  ) internal view returns (uint256) {
    uint256 assetLeafHash = hashNode(amount, offerCanceledOrFinalized);
    uint256 rootHash = assetLeafHash;

    for (uint i = 0; i < 15; i++) {
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
    uint256[31] memory accountMerkleProof
  ) private view returns (uint256) {
    uint256[6] memory inputs;
    inputs[0] = accountNameHash;
    inputs[1] = pubKeyX;
    inputs[2] = pubKeyY;
    inputs[3] = nonce;
    inputs[4] = collectionNonce;
    inputs[5] = assetRoot;
    uint256 accountLeafHash = poseidonT7.poseidon(inputs);
    uint256 rootHash = accountLeafHash;

    for (uint i = 0; i < 31; i++) {
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
    uint256[39] memory nftMerkleProof
  ) private view returns (uint256) {
    uint256[5] memory inputs;
    inputs[0] = creatorAccountIndex;
    inputs[1] = ownerAccountIndex;
    inputs[2] = nftContentHash;
    inputs[3] = creatorTreasuryRate;
    inputs[4] = collectionId;
    uint256 nftLeafHash = poseidonT6.poseidon(inputs);
    uint256 rootHash = nftLeafHash;

    for (uint i = 0; i < 39; i++) {
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
    return poseidonT3.poseidon(inputs);
  }
}
