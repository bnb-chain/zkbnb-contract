// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./ISupportsInterface.sol";

abstract contract SupportsInterface is ISupportsInterface {
  function supportsInterface(bytes4 interfaceID) public pure virtual override returns (bool) {
    return interfaceID == type(ISupportsInterface).interfaceId;
  }
}
