// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface INFTFactory {
  function mintFromZkBNB(
    address _toAddress,
    uint8 _nftContentType,
    uint256 _nftTokenId,
    bytes32 _nftContentHash
  ) external;
}
