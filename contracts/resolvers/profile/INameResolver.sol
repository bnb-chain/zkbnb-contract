// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

interface INameResolver {
    event NameChanged(bytes32 indexed node, string name);

    /**
     * Returns the name associated with an ZNS node, for reverse records.
     * @param node The node to query.
     * @return The associated name.
     */
    function name(bytes32 node) external view returns (string memory);
}
