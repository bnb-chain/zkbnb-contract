// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "../ResolverBase.sol";
import "./IAddrResolver.sol";
import "./IAddressResolver.sol";

abstract contract AddrResolver is IAddrResolver, ResolverBase {

    mapping(bytes32 => address) _addresses;

    /**
     * Sets the address associated with an ZNS node.
     * May only be called by the owner of that node in the ZNS registry.
     * @param node The node to update.
     * @param a The address to set.
     */
    function setAddr(bytes32 node, address a) virtual external authorised(node) {
        _addresses[node] = a;
        AddrChanged(node, a);
    }

    /**
     * Returns the address associated with an ZNS node.
     * @param node The node to query.
     * @return The associated address.
     */
    function addr(bytes32 node) virtual override public view returns (address) {
        return _addresses[node];
    }

    function supportsInterface(bytes4 interfaceID) virtual override public pure returns(bool) {
        return interfaceID == type(IAddrResolver).interfaceId || super.supportsInterface(interfaceID);
    }
}
