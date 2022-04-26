// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

interface IBaseRegistrar {

    event ControllerAdded(address indexed controller);

    event ControllerRemoved(address indexed controller);    // Notify a new owner of one name.

    // Notify a node is registered.
    event ZNSRegistered(string name, bytes32 node, address owner, bytes32 L2Owner);

    // Notify a sub account name is registered to a account with its account public key in L2.
    // event ZNSRegisterSubName(string name, bytes32 childNameHash, bytes32 parentNameHash, address to, bytes32 toL2Account);

    // Notify one name is transferred from one account to another.
    // event ZNSTransfer(bytes32 nameHash, address from, bytes32 fromL2Account, address to, bytes32 toL2Account);

    // Notify one name is transferred from one L2 account to another L2 account.
    // event ZNSL2Transfer(bytes32 name, address owner, bytes32 from, bytes32 to);

    // Authorizes a controller, who can control this registrar.
    function addController(address controller) external;

    // Revoke controller permission for an address.
    function removeController(address controller) external;

    // Set resolver for the node this registrar manages.
    function setThisResolver(address resolver) external;

    // Register a node under the base node.
    function registerZNS(string calldata _name, address _owner, bytes32 zecreyPubKey) external;
}
