// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

import "./ZNS.sol";
import "./IBaseRegistrar.sol";
import "./root/Ownable.sol";
import "./utils/Names.sol";

/**
 * ZNSFIFSRegistrar is a registrar allocating subdomain names to users in Zecrey-Legend in a FIFS way.
 */
contract ZNSFIFSRegistrar is IBaseRegistrar, Ownable {

    using Names for string;

    // ZNS registry
    ZNS public zns;
    // The nodehash/namehash of the root node this registrar owns (eg, .legend)
    bytes32 public baseNode;
    // A map of addresses that are authorized to controll the registrar(eg, register names)
    mapping(address => bool) public controllers;
    // A map to record the L2 owner of each node. A L2 owner can own only 1 name.
    // L2Owner => nodeHash
    mapping(bytes32 => bytes32) ZNSL2OwnerMapper;

    modifier onlyController {
        require(controllers[msg.sender]);
        _;
    }

    modifier live {
        require(zns.owner(baseNode) == address(this));
        _;
    }

    /**
     * Constructor.
     * @param _zns The address of the ZNS registry.
     * @param _node The node that this registrar owns.
     */
    constructor(ZNS _zns, bytes32 _node) {
        zns = _zns;
        baseNode = _node;

        controllers[msg.sender] = true;
    }

    // Authorizes a controller, who can control this registrar.
    function addController(address controller) external override onlyOwner {
        controllers[controller] = true;
        emit ControllerAdded(controller);
    }

    // Revoke controller permission for an address.
    function removeController(address controller) external override onlyOwner {
        controllers[controller] = false;
        emit ControllerRemoved(controller);
    }

    // Set resolver for the node this registrar manages.
    // This msg.sender must be the owner of base node.
    function setThisResolver(address resolver) external override onlyOwner {
        zns.setResolver(baseNode, resolver);
    }

    // Set L2 owner for the node this registrar manages.
    // This msg.sender must be the owner of base node.
    function setThisL2Owner(bytes32 L2Owner) external override onlyOwner {
        zns.setL2Owner(baseNode, L2Owner);
    }

    /**
     * @dev Register a new node under base node if it not exists.
     * @param name The plaintext of the name to register
     * @param owner The address to receive this name
     * @param L2Owner The L2 owner to receive this name
     */
    function register(string calldata name, address owner, bytes32 L2Owner) external override onlyController {
        // Check if this name is valid
        require(_valid(name), "invalid name");
        // This L2 owner should not own any name before
        require(_validL2Owner(L2Owner), "L2 owner existed");

        // Get the name hash
        bytes32 label = keccak256(bytes(name));
        // This subnode should not be registered before
        require(!zns.subNodeRecordExists(baseNode, label), "subnode existed");

        bytes32 subnode = zns.setSubnodeOwner(baseNode, label, owner, L2Owner);

        // Update L2 owner mapper
        ZNSL2OwnerMapper[L2Owner] = subnode;

        emit NameRegistered(name, subnode, owner, L2Owner);
    }

    function _valid(string memory name) internal pure returns (bool) {
        return _validCharset(name) && _validLength(name);
    }

    function _validCharset(string memory name) internal pure returns (bool) {
        return name.charsetValid();
    }

    function _validLength(string memory name) internal pure returns (bool) {
        return name.strlen() >= 3 && name.strlen() <= 32;
    }

    function _validL2Owner(bytes32 L2Owner) internal view returns (bool) {
        return ZNSL2OwnerMapper[L2Owner] == 0x0;
    }
}
