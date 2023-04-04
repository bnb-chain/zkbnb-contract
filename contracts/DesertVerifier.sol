// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./interfaces/IPoseidon.sol";

contract DesertVerifier {
  IPoseidonT3 poseidonT3;
  IPoseidonT6 poseidonT6;
  IPoseidonT7 poseidonT7;

  struct AssetExitData {
    uint16 assetId;
    uint amount;
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
    uint creatorAccountIndex;
    bytes32 nftContentHash;
    uint8 nftContentType;
    uint creatorTreasuryRate;
    uint collectionId;
  }

  constructor(address _poseidonT3, address _poseidonT6, address _poseidonT7) {
    poseidonT3 = IPoseidonT3(_poseidonT3);
    poseidonT6 = IPoseidonT6(_poseidonT6);
    poseidonT7 = IPoseidonT7(_poseidonT7);
  }

  function verifyExitProofBalance(
    uint256 stateRoot,
    uint256 nftRoot,
    AssetExitData calldata assetData,
    AccountExitData calldata accountData,
    uint256[16] memory assetMerkleProof,
    uint256[32] memory accountMerkleProof
  ) external view returns (bool) {
    uint256 assetRoot = getAssetRoot(
      assetData.assetId,
      assetData.amount,
      assetData.offerCanceledOrFinalized,
      assetMerkleProof
    );
    uint256 accountRoot = getAccountRoot(
      accountData.accountId,
      uint256(uint160(accountData.l1Address)),
      uint256(accountData.pubKeyX),
      uint256(accountData.pubKeyY),
      accountData.nonce,
      accountData.collectionNonce,
      assetRoot,
      accountMerkleProof
    );

    return (hashNode(accountRoot, nftRoot) == stateRoot);
  }

  function verifyExitNftProof(
    uint256 stateRoot,
    uint256 assetRoot,
    AccountExitData memory accountData,
    NftExitData[] memory exitNfts,
    uint256[40][] memory nftMerkleProofs,
    uint256[32] memory accountMerkleProof
  ) public view returns (bool) {
    require(exitNfts.length == nftMerkleProofs.length, "wrong length");

    uint256 accountRoot = getAccountRoot(
      accountData.accountId,
      uint256(uint160(accountData.l1Address)),
      uint256(accountData.pubKeyX),
      uint256(accountData.pubKeyY),
      accountData.nonce,
      accountData.collectionNonce,
      assetRoot,
      accountMerkleProof
    );

    for (uint i = 0; i < exitNfts.length; ++i) {
      NftExitData memory nft = exitNfts[i];
      require(nft.ownerAccountIndex == accountData.accountId, "given account is not nft owner");
      uint nftRoot = getNftRoot(
        nft.nftIndex,
        nft.creatorAccountIndex,
        nft.ownerAccountIndex,
        uint256(nft.nftContentHash),
        nft.creatorTreasuryRate,
        nft.collectionId,
        uint256(nft.nftContentType),
        nftMerkleProofs[i]
      );
      if (hashNode(accountRoot, nftRoot) == stateRoot) {
        continue;
      } else {
        return false;
      }
    }

    return true;
  }

  /// assetId - 16 bits
  function getAssetRoot(
    uint16 assetId,
    uint256 amount,
    uint256 offerCanceledOrFinalized,
    uint256[16] memory assetMerkleProof
  ) internal view returns (uint256) {
    require(assetMerkleProof.length == 16, "L1");

    uint256 assetLeafHash = hashNode(amount, offerCanceledOrFinalized);
    uint256 rootHash = assetLeafHash;

    for (uint16 i = 0; i < 16; ++i) {
      uint256 siblingProof = assetMerkleProof[i];
      uint remain = assetId >> i;

      bool isLeft = (remain & 0x01) == 1;

      if (isLeft) {
        rootHash = hashNode(siblingProof, rootHash);
      } else {
        rootHash = hashNode(rootHash, siblingProof);
      }
    }

    return rootHash;
  }

  // accountId - 32 bits
  function getAccountRoot(
    uint32 accountId,
    uint256 l1Address,
    uint256 pubKeyX,
    uint256 pubKeyY,
    uint256 nonce,
    uint256 collectionNonce,
    uint256 assetRoot,
    uint256[32] memory accountMerkleProof
  ) internal view returns (uint256) {
    uint256[6] memory inputs;
    inputs[0] = l1Address;
    inputs[1] = pubKeyX;
    inputs[2] = pubKeyY;
    inputs[3] = nonce;
    inputs[4] = collectionNonce;
    inputs[5] = assetRoot;
    uint256 accountLeafHash = poseidonT7.poseidon(inputs);
    uint256 rootHash = accountLeafHash;

    for (uint16 i = 0; i < 32; ++i) {
      uint256 siblingProof = accountMerkleProof[i];
      uint remain = accountId >> i;
      bool isLeft = (remain & 0x01) == 1;

      if (isLeft) {
        rootHash = hashNode(siblingProof, rootHash);
      } else {
        rootHash = hashNode(rootHash, siblingProof);
      }
    }

    return rootHash;
  }

  /* creatorAccountIndex */
  /* ownerAccountIndex */
  /* nftContentHash */
  /* creatorTreasuryRate */
  /* collectionId */
  /* nftContentType */
  function getNftRoot(
    uint40 nftIndex,
    uint256 creatorAccountIndex,
    uint256 ownerAccountIndex,
    uint256 nftContentHash,
    uint256 creatorTreasuryRate,
    uint256 collectionId,
    uint256 nftContentType,
    uint256[40] memory nftMerkleProof
  ) internal view returns (uint256) {
    uint256[6] memory inputs;
    inputs[0] = creatorAccountIndex;
    inputs[1] = ownerAccountIndex;
    inputs[2] = nftContentHash;
    inputs[3] = creatorTreasuryRate;
    inputs[4] = collectionId;
    inputs[5] = nftContentType;
    uint256 nftLeafHash = poseidonT7.poseidon(inputs);
    uint256 rootHash = nftLeafHash;

    for (uint16 i = 0; i < 40; ++i) {
      uint256 siblingProof = nftMerkleProof[i];
      uint remain = nftIndex >> i;

      bool isLeft = (remain & 0x01) == 1;

      if (isLeft) {
        rootHash = hashNode(siblingProof, rootHash);
      } else {
        rootHash = hashNode(rootHash, siblingProof);
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
