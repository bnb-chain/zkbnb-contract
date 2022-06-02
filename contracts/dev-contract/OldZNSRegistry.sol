// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

import "../ZNS.sol";

contract OldZNSRegistry is ZNS {

    // @dev Require the msg.sender is the owner of this node
    modifier authorized(bytes32 node) {
        require(records[node].owner == msg.sender, "unauthorized");
        _;
    }

    // @dev A Record is a record of node
    struct Record {
        // The owner of a record may:
        // 1. Transfer ownership of the name to another address
        // 2. Change the ownership of sub account name
        // 3. Set the resolver and related information of this node
        address owner;
        address resolver;
        bytes32 pubKey;
        // These fields may be remained for future use.
        // string slot1;
        // string slot2;
    }

    mapping(bytes32 => Record) records; // nameHash of node => Record

    /**
     * @dev Constructs a new registry.
     */
    constructor() {
        records[0x0].owner = msg.sender;
    }

    /**
     * @dev Set the record for a node.
     * @param _node The node to update.
     * @param _owner The address of the new owner.
     * @param _resolver The address of the resolver.
     * @param _pubKey The pub key of the node
     */
    function setRecord(
        bytes32 _node,
        address _owner,
        bytes32 _pubKey,
        address _resolver
    ) external override {
        _setOwner(_node, _owner);
        _setPubKey(_node, _pubKey);
        _setResolver(_node, _resolver);
    }

    /**
     * @dev Set the record for a subnode.
     * @param _node The parent node.
     * @param _label The hash of the subnode
     * @param _owner The address of the new owner.
     * @param _resolver The address of the resolver.
     * @param _pubKey The layer-2 public key
     */
    function setSubnodeRecord(
        bytes32 _node,
        bytes32 _label,
        address _owner,
        bytes32 _pubKey,
        address _resolver
    ) external override returns (bytes32){
        bytes32 subnode = setSubnodeOwner(_node, _label, _owner, _pubKey);
        _setResolver(subnode, _resolver);
        return subnode;
    }

    /**
     * @dev Set the ownership of a subnode hash(node, label) to a new address. May only be called by the owner of the parent node.
     * @param _node The parent node.
     * @param _label The hash of the label specifying the subnode.
     * @param _owner The address of the new owner.
     * @param _pubKey The L2 owner of the subnode
     */
    function setSubnodeOwner(
        bytes32 _node,
        bytes32 _label,
        address _owner,
        bytes32 _pubKey
    ) public override authorized(_node) returns (bytes32) {
        bytes32 subnode = keccak256Hash(abi.encodePacked(_node, _label));
        _setOwner(subnode, _owner);
        _setPubKey(subnode, _pubKey);
        return subnode;
    }

    /**
     * @dev Set the resolver address for the specified node.
     * @param _node The node to update.
     * @param _resolver The address of the resolver.
     */
    function setResolver(bytes32 _node, address _resolver) public override authorized(_node) {
        _setResolver(_node, _resolver);
    }

    /**
     * @dev Returns the address that owns the specified node.
     * @param node The specified node.
     * @return address of the owner.
     */
    function owner(bytes32 node) public view override returns (address) {
        address addr = records[node].owner;
        if (addr == address(this)) {
            return address(0x0);
        }

        return addr;
    }

    /**
     * @dev Returns the address of the resolver for the specified node.
     * @param node The specified node.
     * @return address of the resolver.
     */
    function resolver(bytes32 node) public view override returns (address) {
        return records[node].resolver;
    }

    /**
     * @dev Returns the L2 owner of the specified node, which is a bytes32 L2 public key.
     * @param node The specified node.
     * @return L2 owner of the node.
     */
    function pubKey(bytes32 node) public view override returns (bytes32) {
        return records[node].pubKey;
    }

    /**
     * @dev Returns whether a record has been imported to the registry.
     * @param node The specified node
     * @return bool If record exists
     */
    function recordExists(bytes32 node) public view override returns (bool) {
        return _exists(node);
    }

    /**
     * @dev Returns whether a subnode record has been imported to the registry.
     * @param node The specified node
     * @param label The nodehash of the subnode
     * @return bool If record exists
     */
    function subNodeRecordExists(bytes32 node, bytes32 label) public view override returns (bool) {
        bytes32 subnode = keccak256Hash(abi.encodePacked(node, label));
        return _exists(subnode);
    }

    function _setResolver(bytes32 _node, address _resolver) internal {
        if (_resolver != records[_node].resolver) {
            records[_node].resolver = _resolver;
            emit NewResolver(_node, _resolver);
        }
    }

    function _setOwner(bytes32 _node, address _owner) internal {
        if (_owner != records[_node].owner) {
            records[_node].owner = _owner;
            emit NewOwner(_node, _owner);
        }
    }

    function _setPubKey(bytes32 _node, bytes32 _pubKey) internal {
        if (_pubKey != records[_node].pubKey) {
            records[_node].pubKey = _pubKey;
            emit NewPubKey(_node, _pubKey);
        }
    }

    function _exists(bytes32 node) internal view returns (bool) {
        return records[node].owner != address(0x0);
    }

    function keccak256Hash(bytes memory input) public view returns (bytes32 result) {
        result = keccak256(input);
    }

}
