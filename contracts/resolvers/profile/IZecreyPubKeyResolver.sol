// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

interface IZecreyPubKeyResolver {

    event ZecreyPubKeyChanged(bytes32 indexed node, bytes32 pubKeyX, bytes32 pubKeyY);

    /**
     * Returns the public key in L2 associated with an ZNS node.
     * @param node The node to query
     * @return pubKeyX The public key in L2 owns this node
     * @return pubKeyY The public key in L2 owns this node
     */
    function zecreyPubKey(bytes32 node) external view returns (bytes32 pubKeyX, bytes32 pubKeyY);
}
