// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./SupportsInterface.sol";

abstract contract ResolverBase is SupportsInterface {
  modifier authorised(bytes32 node) {
    require(isAuthorised(node));
    _;
  }

  function isAuthorised(bytes32 node) internal view virtual returns (bool);
}
