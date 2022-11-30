// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./SupportsInterface.sol";

abstract contract ResolverBase is SupportsInterface {
  function isAuthorised(bytes32 node) internal view virtual returns (bool);

  modifier authorised(bytes32 node) {
    require(isAuthorised(node));
    _;
  }
}
