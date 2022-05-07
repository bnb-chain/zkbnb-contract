// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

import "./ZNS.sol";
import "./IBaseRegistrar.sol";
import "./Ownable.sol";
import "./utils/Names.sol";
import "./ReentrancyGuard.sol";

/**
 * ZNSController is a registrar allocating subdomain names to users in Zecrey-Legend in a FIFS way.
 */
contract ZNSController is IBaseRegistrar, Ownable, ReentrancyGuard {

    using Names for string;

    // ZNS registry
    ZNS public zns;

    // The nodehash/namehash of the root node this registrar owns (eg, .legend)
    bytes32 public baseNode;
    // A map of addresses that are authorized to controll the registrar(eg, register names)
    mapping(address => bool) public controllers;
    // A map to record the L2 owner of each node. A L2 owner can own only 1 name.
    // pubKey => nodeHash
    mapping(bytes32 => bytes32) ZNSPubKeyMapper;

    modifier onlyController {
        require(controllers[msg.sender]);
        _;
    }

    modifier live {
        require(zns.owner(baseNode) == address(this));
        _;
    }

    function initialize(bytes calldata initializationParameters) external {
        initializeReentrancyGuard();
        (address _znsAddr, bytes32 _node) = abi.decode(initializationParameters, (address, bytes32));
        zns = ZNS(_znsAddr);
        baseNode = _node;
        controllers[msg.sender] = true;
    }

    // Authorizes a controller, who can control this registrar.
    function addController(address _controller) external override onlyOwner {
        controllers[_controller] = true;
        emit ControllerAdded(_controller);
    }

    // Revoke controller permission for an address.
    function removeController(address _controller) external override onlyOwner {
        controllers[_controller] = false;
        emit ControllerRemoved(_controller);
    }

    // Set resolver for the node this registrar manages.
    // This msg.sender must be the owner of base node.
    function setThisResolver(address _resolver) external override onlyOwner {
        zns.setResolver(baseNode, _resolver);
    }

    function getOwner(bytes32 node) external view returns (address){
        return zns.owner(node);
    }

    /**
     * @dev Register a new node under base node if it not exists.
     * @param _name The plaintext of the name to register
     * @param _owner The address to receive this name
     * @param _pubKey The pub key of the owner
     */
    function registerZNS(string calldata _name, address _owner, bytes32 _pubKey, address _resolver) external override onlyController {
        // Check if this name is valid
        require(_valid(_name), "invalid name");
        // This L2 owner should not own any name before
        require(_validPubKey(_pubKey), "pub key existed");

        // Get the name hash
        bytes32 label = keccak256(bytes(_name));
        // This subnode should not be registered before
        require(!zns.subNodeRecordExists(baseNode, label), "subnode existed");

        bytes32 subnode = zns.setSubnodeRecord(baseNode, label, _owner, _pubKey, _resolver);

        // Update L2 owner mapper
        ZNSPubKeyMapper[_pubKey] = subnode;

        emit ZNSRegistered(_name, subnode, _owner, _pubKey);
    }

    function isRegisteredHash(bytes32 _nameHash) external view returns (bool){
        return zns.recordExists(_nameHash);
    }

    function _valid(string memory _name) internal pure returns (bool) {
        return _validCharset(_name) && _validLength(_name);
    }

    function _validCharset(string memory _name) internal pure returns (bool) {
        return _name.charsetValid();
    }

    function _validLength(string memory _name) internal pure returns (bool) {
        return _name.strlen() >= 3 && _name.strlen() <= 32;
    }

    function _validPubKey(bytes32 _pubKey) internal view returns (bool) {
        return ZNSPubKeyMapper[_pubKey] == 0x0;
    }
}
