// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

interface IPubKeyResolver {

    event PubKeyChanged(bytes32 indexed node, bytes32 x, bytes32 y);

    /**
     * Returns the SECP256k1 public key in L1 associated with an ZNS node.
     * @param node The node to query
     * @return x The X coordinate of the curve point for the public key.
     * @return y The Y coordinate of the curve point for the public key.
     */
    function pubKey(bytes32 node) external view returns (bytes32 x, bytes32 y);
}
