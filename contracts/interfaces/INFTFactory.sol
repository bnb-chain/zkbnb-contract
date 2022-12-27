// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTFactory {
  function mintFromZkBNB(
    address _creatorAddress,
    address _toAddress,
    uint256 _nftTokenId,
    bytes memory _extraData
  ) external;

  event MintNFTFromZkBNB(
    address indexed _creatorAddress,
    address indexed _toAddress,
    uint256 _nftTokenId,
    bytes _extraData
  );
}
