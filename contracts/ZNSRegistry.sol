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
        bytes32 L2Owner;
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
     * @param node The node to update.
     * @param owner The address of the new owner.
     * @param resolver The address of the resolver.
     * @param L2Owner The L2Owner of the node
     */
    function setRecord(
        bytes32 node,
        address owner,
        bytes32 L2Owner,
        address resolver
    ) external override {
        setOwner(node, owner);
        _setL2Owner(node, L2Owner);
        _setResolver(node, resolver);
    }

    /**
     * @dev Set the record for a subnode.
     * @param node The parent node.
     * @param label The hash of the subnode name
     * @param owner The address of the new owner.
     * @param resolver The address of the resolver.
     * @param L2Owner The L2Owner of the subnode
     */
    function setSubnodeRecord(
        bytes32 node,
        bytes32 label,
        address owner,
        bytes32 L2Owner,
        address resolver
    ) external override returns (bytes32){
        bytes32 subnode = setSubnodeOwner(node, label, owner, L2Owner);
        _setResolver(subnode, resolver);
        return subnode;
    }

    /**
     * @dev Set the ownership of a node to a new address. May only be called by the current owner of the node.
     * @param node The node to transfer ownership of.
     * @param owner The address of the new owner.
     */
    function setOwner(bytes32 node, address owner) public override authorized(node) {
        _setOwner(node, owner);
    }

    /**
     * @dev Set the ownership of a subnode keccak256(node, label) to a new address. May only be called by the owner of the parent node.
     * @param node The parent node.
     * @param label The hash of the label specifying the subnode.
     * @param owner The address of the new owner.
     * @param L2Owner The L2 owner of the subnode
     */
    function setSubnodeOwner(
        bytes32 node,
        bytes32 label,
        address owner,
        bytes32 L2Owner
    ) public override authorized(node) returns (bytes32) {
        bytes32 subnode = keccak256(abi.encodePacked(node, label));
        _setOwner(subnode, owner);
        _setL2Owner(subnode, L2Owner);
        return subnode;
    }

    /**
     * @dev Set the resolver address for the specified node.
     * @param node The node to update.
     * @param resolver The address of the resolver.
     */
    function setResolver(bytes32 node, address resolver) public override authorized(node) {
        _setResolver(node, resolver);
    }

    /**
     * @dev Set the L2 owner for the specified node.
     * @param node The node to update.
     * @param L2Owner The bytes32 public key of the L2 owner.
     */
    function setL2Owner(bytes32 node, bytes32 L2Owner) public override authorized(node) {
        _setL2Owner(node, L2Owner);
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
    function L2Owner(bytes32 node) public view override returns (bytes32) {
        return records[node].L2Owner;
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

    function _setResolver(bytes32 node, address resolver) internal {
        if (resolver != records[node].resolver) {
            records[node].resolver = resolver;
            emit NewResolver(node, resolver);
        }
    }

    function _setOwner(bytes32 node, address owner) internal {
        if (owner != records[node].owner) {
            records[node].owner = owner;
            emit NewOwner(node, owner);
        }
    }

    function _setL2Owner(bytes32 node, bytes32 L2Owner) internal {
        if (L2Owner != records[node].L2Owner) {
            records[node].L2Owner = L2Owner;
            emit NewL2Owner(node, L2Owner);
        }
    }

    function _exists(bytes32 node) internal view returns (bool) {
        return records[node].owner != address(0x0);
    }
}
