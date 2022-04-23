// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

import "./ZNS.sol";
import "hardhat/console.sol";

contract ZNSRegistry is ZNS {

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
        // 3. Change the L2 owner of this account name
        // 4. Set the ttl and resolver of node
        address owner;
        bytes32 zecreyPubKey;
        address resolver;
        // bool dirty; // dirty is a flag to indicate whether the L2Owner of a node is set
    }

    mapping(bytes32 => Record) records; // nameHash of node => Record

    /**
     * @dev Constructs a new registry.
     */
    constructor() {
        records[0x0].owner = msg.sender;
    }

    //    /**
    //     * @dev Transfer a name to another account with its L2 account
    //     * @param nameHash The hashed specified name
    //     * @param to The mew address to receive this name
    //     * @param toL2Account The new L2 address to receive this name
    //     */
    //    function transfer(bytes32 nameHash, address to, bytes32 toL2Account) external authorized(nameHash) {
    //        // This toL2Account should not owned any name in L2
    //        require(_L2AccountValid(toL2Account), "L2 account has owned an account name");
    //
    //        // Get original owner of this name
    //        address from = records[nameHash].owner;
    //        bytes32 fromL2Account = records[nameHash].L2Owner;
    //        require(from == msg.sender, "unauthorized");
    //
    //        _setOwner(nameHash, to, toL2Account);
    //
    //        emit ZNSTransfer(nameHash, from, fromL2Account, to, toL2Account);
    //    }
    //
    //    /**
    //     * @dev Transfer a name to another account in L2, this operation must be sent by this name's owner
    //     * @param nameHash The hashed specified name
    //     * @param toL2Account The new L2 address to receive this name
    //     */
    //    function transferL2(bytes32 nameHash, bytes32 toL2Account) external authorized(nameHash) {
    //        // This toL2Account should not owned any name in L2.
    //        require(_L2AccountValid(toL2Account), "L2 account has owned an account name");
    //
    //        // Get original owner of this name
    //        address addr = records[nameHash].owner;
    //        bytes32 fromL2Account = records[nameHash].L2Owner;
    //        require(addr == msg.sender, "unauthorized");
    //
    //        _setL2Owner(nameHash, toL2Account);
    //
    //        emit ZNSL2Transfer(nameHash, addr, fromL2Account, toL2Account);
    //    }

    /**
     * @dev Set the record for a node.
     * @param _node The node to update.
     * @param _owner The address of the new owner.
     * @param _resolver The address of the resolver.
     * @param _zecreyPubKey The L2Owner of the node
     */
    function setRecord(
        bytes32 _node,
        address _owner,
        bytes32 _zecreyPubKey,
        address _resolver
    ) external override {
        setOwner(_node, _owner);
        _setZecreyPubKey(_node, _zecreyPubKey);
        _setResolver(_node, _resolver);
    }

    /**
     * @dev Set the record for a subnode.
     * @param _node The parent node.
     * @param _label The hash of the subnode name
     * @param _owner The address of the new owner.
     * @param _resolver The address of the resolver.
     * @param _zecreyPubKey The L2Owner of the subnode
     */
    function setSubnodeRecord(
        bytes32 _node,
        bytes32 _label,
        address _owner,
        bytes32 _zecreyPubKey,
        address _resolver
    ) external override returns (bytes32){
        bytes32 subnode = setSubnodeOwner(_node, _label, _owner, _zecreyPubKey);
        _setResolver(subnode, _resolver);
        return subnode;
    }

    /**
     * @dev Set the ownership of a node to a new address. May only be called by the current owner of the node.
     * @param _node The node to transfer ownership of.
     * @param _owner The address of the new owner.
     */
    function setOwner(bytes32 _node, address _owner) public override authorized(_node) {
        _setOwner(_node, _owner);
    }

    /**
     * @dev Set the ownership of a subnode keccak256(node, label) to a new address. May only be called by the owner of the parent node.
     * @param _node The parent node.
     * @param _label The hash of the label specifying the subnode.
     * @param _owner The address of the new owner.
     * @param _zecreyPubKey The L2 owner of the subnode
     */
    function setSubnodeOwner(
        bytes32 _node,
        bytes32 _label,
        address _owner,
        bytes32 _zecreyPubKey
    ) public override authorized(_node) returns (bytes32) {
        bytes32 subnode = keccak256(abi.encodePacked(_node, _label));
        _setOwner(subnode, _owner);
        _setZecreyPubKey(subnode, _zecreyPubKey);
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
     * @dev Set the L2 owner for the specified node.
     * @param _node The node to update.
     * @param _zecreyPubKey The bytes32 public key of the L2 owner.
     */
    function setZecreyPubKey(bytes32 _node, bytes32 _zecreyPubKey) public override authorized(_node) {
        _setZecreyPubKey(_node, _zecreyPubKey);
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
    function zecreyPubKey(bytes32 node) public view override returns (bytes32) {
        return records[node].zecreyPubKey;
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
     * @param label The namehash of the subnode
     * @return bool If record exists
     */
    function subNodeRecordExists(bytes32 node, bytes32 label) public view override returns (bool) {
        bytes32 subnode = keccak256(abi.encodePacked(node, label));
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

    function _setZecreyPubKey(bytes32 _node, bytes32 _zecreyPubKey) internal {
        if (_zecreyPubKey != records[_node].zecreyPubKey) {
            records[_node].zecreyPubKey = _zecreyPubKey;
            emit NewZecreyPubKey(_node, _zecreyPubKey);
        }
    }

    function _exists(bytes32 node) internal view returns (bool) {
        return records[node].owner != address(0x0);
    }
}
