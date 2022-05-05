// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

/**
 * Interface for the legacy L1 addr function.
 */
interface IAddrResolver {
    event AddrChanged(bytes32 indexed node, address a);

    /**
     * Returns the L1 address associated with an node.
     * @param node The node to query.
     * @return The associated address.
     */
    function addr(bytes32 node) external view returns (address);
}
