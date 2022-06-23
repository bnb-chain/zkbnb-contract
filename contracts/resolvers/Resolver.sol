//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "./profile/INameResolver.sol";
import "./ISupportsInterface.sol";
import "./profile/IABIResolver.sol";
import "./profile/IAddrResolver.sol";
import "./profile/IPubKeyResolver.sol";
import "./profile/IZkbasPubKeyResolver.sol";

/**
 * A generic resolver interface which includes all the functions including the ones deprecated
 */
interface Resolver is
    ISupportsInterface,
    IABIResolver,
    IAddrResolver,
    IZkbasPubKeyResolver,
    IPubKeyResolver,
    INameResolver
{
    function setABI(
        bytes32 node,
        uint256 contentType,
        bytes calldata data
    ) external;

    function setAddr(bytes32 node, address addr) external;

    function setName(bytes32 node, string calldata _name) external;

    function setPubKey(
        bytes32 node,
        bytes32 x,
        bytes32 y
    ) external;

    // not support yet
//    function setZkbasPubKey(
//        bytes32 node,
//        bytes32 zkbasPubKey
//    ) external;

    function multicall(bytes[] calldata data) external returns (bytes[] memory results);
}
