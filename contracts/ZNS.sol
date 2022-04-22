// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

interface ZNS {

    // Logged when a node has new owner
    // Note that node is a namehash of a specified node, label is a namehash of subnode.
    event NewOwner(bytes32 indexed node, address owner);

    // Logged when the L2 owner of a node transfers ownership to a new L2 account.
    event NewL2Owner(bytes32 indexed node, bytes32 L2Owner);

    // Logged when the resolver for a node changes.
    event NewResolver(bytes32 indexed node, address resolver);

    function setRecord(
        bytes32 node,
        address owner,
        bytes32 L2Owner,
        address resolver
    ) external;

    function setSubnodeRecord(
        bytes32 node,
        bytes32 label,
        address owner,
        bytes32 L2Owner,
        address resolver
    ) external returns (bytes32);

    function setSubnodeOwner(
        bytes32 node,
        bytes32 label,
        address owner,
        bytes32 L2Owner
    ) external returns (bytes32);

    function setResolver(bytes32 node, address resolver) external;

    function setOwner(bytes32 node, address owner) external;

    function setL2Owner(bytes32 node, bytes32 L2Owner) external;

    function resolver(bytes32 node) external view returns (address);

    function owner(bytes32 node) external view returns (address);

    function L2Owner(bytes32 node) external view returns (bytes32);

    function recordExists(bytes32 node) external view returns (bool);

    function subNodeRecordExists(bytes32 node, bytes32 label) external view returns (bool);

}
