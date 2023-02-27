// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./interfaces/IPoseidon.sol";

contract ExodusVerifier {
  IPoseidonT3 poseidonT3;
  IPoseidonT6 poseidonT6;
  IPoseidonT7 poseidonT7;

  struct ExitData {
    uint32 assetId;
    uint32 accountId;
    uint amount;
    uint offerCanceledOrFinalized;
    bytes32 accountNameHash;
    bytes32 pubKeyX;
    bytes32 pubKeyY;
    uint nonce;
    uint collectionNonce;
  }

  struct ExitNftData {
    uint64 nftIndex;
    uint creatorAccountIndex;
    bytes32 nftContentHash;
    uint creatorTreasuryRate;
    uint collectionId;
  }

  /* struct ExitNftData { */
  /*   uint ownerAccountIndex; */
  /*   NftData[] nftData;; // list of NFTs to exit */
  /* } */

  constructor(address _poseidonT3, address _poseidonT6, address _poseidonT7) {
    poseidonT3 = IPoseidonT3(_poseidonT3);
    poseidonT6 = IPoseidonT6(_poseidonT6);
    poseidonT7 = IPoseidonT7(_poseidonT7);
  }

  function verifyExitProofBalance(
    uint256 stateRoot,
    uint256 nftRoot,
    ExitData calldata exitData,
    bytes32[15] memory assetMerkleProof,
    bytes32[31] memory accountMerkleProof
  ) external view returns (bool) {
    uint256 assetRoot = getAssetRoot(
      exitData.assetId,
      exitData.amount,
      exitData.offerCanceledOrFinalized,
      assetMerkleProof
    );
    uint256 accountRoot = getAccountRoot(
      exitData.accountId,
      uint256(exitData.accountNameHash),
      uint256(exitData.pubKeyX),
      uint256(exitData.pubKeyY),
      exitData.nonce,
      exitData.collectionNonce,
      assetRoot,
      accountMerkleProof
    );
    return (hashNode(accountRoot, nftRoot) == stateRoot);
  }

  function verifyExitNftProof(
    uint256 stateRoot,
    uint256 accountRoot,
    uint ownerAccountIndex,
    ExitNftData[] memory exitNfts, // suppose 100 nfts exit at once
    bytes32[39][] memory nftMerkleProofs
  ) public view returns (bool) {
    require(exitNfts.length == nftMerkleProofs.length, "wrong length");

    for (uint i = 0; i < exitNfts.length; i++) {
      ExitNftData memory nft = exitNfts[i];
      bytes32[39] memory proofs = nftMerkleProofs[i];
      uint nftRoot = getNftRoot(
        nft.nftIndex,
        nft.creatorAccountIndex,
        ownerAccountIndex,
        uint256(nft.nftContentHash),
        nft.creatorTreasuryRate,
        nft.collectionId,
        proofs
      );
      if (hashNode(accountRoot, nftRoot) == stateRoot) {
        continue;
      } else {
        return false;
      }
    }

    return true;
  }

  function getAssetRoot(
    uint256 assetId,
    uint256 amount,
    uint256 offerCanceledOrFinalized,
    bytes32[15] memory assetMerkleProof
  ) internal view returns (uint256) {
    uint256 assetLeafHash = hashNode(amount, offerCanceledOrFinalized);
    uint256 rootHash = assetLeafHash;

    for (uint i = 0; i < 15; i++) {
      if (assetId % 2 == 0) {
        rootHash = hashNode(rootHash, uint256(assetMerkleProof[i]));
      } else {
        rootHash = hashNode(uint256(assetMerkleProof[i]), rootHash);
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
    bytes32[31] memory accountMerkleProof
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
        rootHash = hashNode(rootHash, uint256(accountMerkleProof[i]));
      } else {
        rootHash = hashNode(uint256(accountMerkleProof[i]), rootHash);
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
    bytes32[39] memory nftMerkleProof
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
        rootHash = hashNode(rootHash, uint256(nftMerkleProof[i]));
      } else {
        rootHash = hashNode(uint256(nftMerkleProof[i]), rootHash);
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
