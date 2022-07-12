// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./IPubKeyResolver.sol";
import "../ResolverBase.sol";

abstract contract PubKeyResolver is IPubKeyResolver, ResolverBase {
    struct PublicKey {
        bytes32 x;
        bytes32 y;
    }

    mapping(bytes32 => PublicKey) pubkeys;

    /**
     * Sets the SECP256k1 public key associated with an ZNS node.
     * @param node The node to query
     * @param x the X coordinate of the curve point for the public key.
     * @param y the Y coordinate of the curve point for the public key.
     */
    function setPubKey(bytes32 node, bytes32 x, bytes32 y) virtual external authorised(node) {
        pubkeys[node] = PublicKey(x, y);
        emit PubKeyChanged(node, x, y);
    }

    /**
     * Returns the SECP256k1 public key in Layer 1 associated with an ZNS node.
     * @param node The node to query
     * @return x The X coordinate of the curve point for the public key.
     * @return y The Y coordinate of the curve point for the public key.
     */
    function pubKey(bytes32 node) virtual override external view returns (bytes32 x, bytes32 y) {
        return (pubkeys[node].x, pubkeys[node].y);
    }

    function supportsInterface(bytes4 interfaceID) virtual override public pure returns (bool) {
        return interfaceID == type(IPubKeyResolver).interfaceId || super.supportsInterface(interfaceID);
    }
}
