// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

import "./ZNS.sol";
import "./IBaseRegistrar.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./utils/Names.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./IPriceOracle.sol";

/**
 * ZNSController is a registrar allocating subdomain names to users in Zkbas in a FIFS way.
 */
contract ZNSController is IBaseRegistrar, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    using Names for string;

    // ZNS registry
    ZNS public zns;
    // Price Oracle
    IPriceOracle public prices;

    event Withdraw(address _to, uint256 _value);

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

    function initialize(bytes calldata initializationParameters) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        (address _znsAddr, address _prices, bytes32 _node) = abi.decode(initializationParameters, (address, address, bytes32));
        zns = ZNS(_znsAddr);
        prices = IPriceOracle(_prices);
        baseNode = _node;

        // initialize ownership
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
     * @param _pubKeyX The pub key of the owner
     * @param _pubKeyY The pub key of the owner
     */
    function registerZNS(string calldata _name, address _owner, bytes32 _pubKeyX, bytes32 _pubKeyY, address _resolver) external override onlyController payable returns (bytes32 subnode, uint32 accountIndex){
        // Check if this name is valid
        require(_valid(_name), "invalid name");
        // This L2 owner should not own any name before
        require(_validPubKey(_pubKeyY), "pub key existed");
        // Calculate price using PriceOracle
        uint256 price = prices.price(_name);
        // Check enough value
        require(
            msg.value >= price,
            "nev"
        );

        // Get the name hash
        bytes32 label = mimcHash(bytes(_name));
        // This subnode should not be registered before
        require(!zns.subNodeRecordExists(baseNode, label), "subnode existed");
        // Register subnode
        subnode = zns.setSubnodeRecord(baseNode, label, _owner, _pubKeyX, _pubKeyY, _resolver);
        accountIndex = zns.setSubnodeAccountIndex(subnode);

        // Update L2 owner mapper
        ZNSPubKeyMapper[_pubKeyY] = subnode;

        emit ZNSRegistered(_name, subnode, _owner, _pubKeyX, _pubKeyY, price);

        // Refund remained value to the owner of this name
        if (msg.value > price) {
            payable(_owner).transfer(
                msg.value - price
            );
        }

        return (subnode, accountIndex);
    }

    /**
     * @dev Withdraw BNB from this contract, only called by the owner of this contract.
     * @param _to The address to receive
     * @param _value The BNB amount to withdraw
     */
    function withdraw(address _to, uint256 _value) external onlyOwner {
        // Check not too much value
        require(_value < address(this).balance, "tmv");
        // Withdraw
        payable(_to).transfer(_value);

        emit Withdraw(_to, _value);
    }

    function getSubnodeNameHash(string memory name) external view returns (bytes32) {
        return mimcHash(abi.encodePacked(baseNode, mimcHash(bytes(name))));
    }

    function isRegisteredNameHash(bytes32 _nameHash) external view returns (bool){
        return zns.recordExists(_nameHash);
    }

    function isRegisteredZNSName(string memory _name) external view returns (bool) {
        bytes32 subnode = this.getSubnodeNameHash(_name);
        return this.isRegisteredNameHash(subnode);
    }

    function getZNSNamePrice(string calldata name) external view returns (uint256) {
        return prices.price(name);
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

    function _validPubKey(bytes32 _pubKeyY) internal view returns (bool) {
        return ZNSPubKeyMapper[_pubKeyY] == 0x0;
    }

    function mimcHash(bytes memory input) public view returns (bytes32 result) {
        address mimcContract = 0x0000000000000000000000000000000000000013;

        (bool success, bytes memory data) = mimcContract.staticcall(input);
        require(success, "Q");
        assembly {
            result := mload(add(data, 32))
        }
    }


}
