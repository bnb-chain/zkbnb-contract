// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

interface ZNS {

    // Logged when a node has new owner
    // Note that node is a namehash of a specified node, label is a namehash of subnode.
    event NewOwner(bytes32 indexed node, address owner);

    // Logged when the L2 owner of a node transfers ownership to a new L2 account.
    event NewPubKey(bytes32 indexed node, bytes32 pubKey);

    // Logged when the resolver for a node changes.
    event NewResolver(bytes32 indexed node, address resolver);

    function setRecord(
        bytes32 _node,
        address _owner,
        bytes32 _pubKey,
        address _resolver
    ) external;

    function setSubnodeRecord(
        bytes32 _node,
        bytes32 _label,
        address _owner,
        bytes32 _pubKey,
        address _resolver
    ) external returns (bytes32);

    function setSubnodeOwner(
        bytes32 _node,
        bytes32 _label,
        address _owner,
        bytes32 _pubKey
    ) external returns (bytes32);

    function setResolver(bytes32 _node, address _resolver) external;

    function resolver(bytes32 node) external view returns (address);

    function owner(bytes32 node) external view returns (address);

    function pubKey(bytes32 node) external view returns (bytes32);

    function recordExists(bytes32 node) external view returns (bool);

    function subNodeRecordExists(bytes32 node, bytes32 label) external view returns (bool);

}
