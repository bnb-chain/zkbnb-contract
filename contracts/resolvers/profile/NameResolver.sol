// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "../ResolverBase.sol";
import "./INameResolver.sol";

abstract contract NameResolver is INameResolver, ResolverBase {
  mapping(bytes32 => string) names;

  /**
   * Sets the name associated with an ZNS node, for reverse records.
   * May only be called by the owner of that node in the ZNS registry.
   * @param node The node to update.
   */
  function setName(bytes32 node, string calldata newName) external virtual authorised(node) {
    names[node] = newName;
    emit NameChanged(node, newName);
  }

  /**
   * Returns the name associated with an ZNS node, for reverse records.
   * @param node The node to query.
   * @return The associated name.
   */
  function name(bytes32 node) external view virtual override returns (string memory) {
    return names[node];
  }

  function supportsInterface(bytes4 interfaceID) public pure virtual override returns (bool) {
    return interfaceID == type(INameResolver).interfaceId || super.supportsInterface(interfaceID);
  }
}
