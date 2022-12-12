// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISupportsInterface {
  // @see The supportsInterface function is documented in EIP-165
  function supportsInterface(bytes4 interfaceID) external pure returns (bool);
}
