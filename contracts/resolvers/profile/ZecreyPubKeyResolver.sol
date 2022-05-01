// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "../ResolverBase.sol";
import "./IZecreyPubKeyResolver.sol";
import "../../ZNS.sol";

abstract contract ZecreyPubKeyResolver is IZecreyPubKeyResolver, ResolverBase {

    /**
     * Returns the public key in L2 associated with an ZNS node.
     * @param node The node to query
     * @return pubKey The public key in L2 owns this node
     */
    function zecreyPubKey(bytes32 node) virtual override external view returns (bytes32 pubKey);

    function supportsInterface(bytes4 interfaceID) virtual override public pure returns (bool) {
        return interfaceID == type(IZecreyPubKeyResolver).interfaceId || super.supportsInterface(interfaceID);
    }
}
