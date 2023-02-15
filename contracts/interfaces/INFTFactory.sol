// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTFactory {
  event MintNFTFromZkBNB(
    address indexed _creatorAddress,
    address indexed _toAddress,
    uint256 _nftTokenId,
    bytes32 _nftContentHash,
    bytes _extraData
  );

  function mintFromZkBNB(
    address _creatorAddress,
    address _toAddress,
    uint256 _nftTokenId,
    bytes32 _nftContentHash,
    bytes memory _extraData
  ) external;
}
