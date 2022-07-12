// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

interface IBaseRegistrar {

    event ControllerAdded(address indexed controller);

    event ControllerRemoved(address indexed controller);

    // Notify a node is registered.
    event ZNSRegistered(string name, bytes32 node, address owner, bytes32 pubKeyX, bytes32 pubKeyY, uint256 price);

    // Authorizes a controller, who can control this registrar.
    function addController(address controller) external;

    // Revoke controller permission for an address.
    function removeController(address controller) external;

    // Set resolver for the node this registrar manages.
    function setThisResolver(address resolver) external;

    // Register a node under the base node.
    function registerZNS(string calldata _name, address _owner, bytes32 zecreyPubKeyX, bytes32 zecreyPubKeyY, address _resolver) external payable returns (bytes32, uint32);
}
