// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "../ResolverBase.sol";
import "./IZkbasPubKeyResolver.sol";
import "../../ZNS.sol";

abstract contract ZkbasPubKeyResolver is IZkbasPubKeyResolver, ResolverBase {

    /**
     * Returns the public key in L2 associated with an ZNS node.
     * @param node The node to query
     * @return pubKeyX The public key in L2 owns this node
     * @return pubKeyY The public key in L2 owns this node
     */
    function zkbasPubKey(bytes32 node) virtual override external view returns (bytes32 pubKeyX, bytes32 pubKeyY);

    function supportsInterface(bytes4 interfaceID) virtual override public pure returns (bool) {
        return interfaceID == type(IZkbasPubKeyResolver).interfaceId || super.supportsInterface(interfaceID);
    }
}
