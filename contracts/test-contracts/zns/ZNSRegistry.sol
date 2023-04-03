// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./interfaces/IZNS.sol";

contract ZNSRegistry is IZNS {
  // @dev A Record is a record of node
  struct Record {
    // The owner of a record may:
    // 1. Transfer ownership of the name to another address
    // 2. Change the ownership of sub account name
    // 3. Set the resolver and related information of this node
    address owner;
    address resolver;
    bytes32 pubKeyX;
    bytes32 pubKeyY;
    uint32 accountIndex;
    // These fields may be remained for future use.
    // string slot1;
    // string slot2;
  }
  uint256 immutable q = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
  mapping(bytes32 => Record) records; // nameHash of node => Record
  uint32 count = 0;

  // @dev Top level domains allowed in the registry such as ".zkbnb"
  mapping(bytes32 => bool) public topLevelDomains;

  /**
   * @dev Constructs a new registry.
   */
  constructor() {
    records[0x0].owner = msg.sender;
    topLevelDomains[0x0] = true;
  }

  // @dev Require the msg.sender is the owner of this node
  modifier authorized(bytes32 node) {
    require(records[node].owner == msg.sender, "unauthorized");
    require(topLevelDomains[node], "node not allowed");
    _;
  }

  /**
   * @dev Set the record for a subnode.
   * @param _node The parent node.
   * @param _label The hash of the subnode
   * @param _owner The address of the new owner.
   * @param _resolver The address of the resolver.
   * @param _pubKeyX The layer-2 public key
   * @param _pubKeyY The layer-2 public key
   * @return subnode The name hash of the newly created label
   * @return accountIndex The index of the created account name
   */
  function setSubnodeRecord(
    bytes32 _node,
    bytes32 _label,
    address _owner,
    bytes32 _pubKeyX,
    bytes32 _pubKeyY,
    address _resolver
  ) external override returns (bytes32, uint32) {
    bytes32 subnode = setSubnodeOwner(_node, _label, _owner, _pubKeyX, _pubKeyY);
    _setResolver(subnode, _resolver);
    records[subnode].accountIndex = count;
    ++count;
    return (subnode, records[subnode].accountIndex);
  }

  /**
   * @dev Set the ownership of a subnode hash(node, label) to a new address. May only be called by the owner of the parent node.
   * @param _node The parent node.
   * @param _label The hash of the label specifying the subnode.
   * @param _owner The address of the new owner.
   * @param _pubKeyX The L2 owner of the subnode
   * @param _pubKeyY The L2 owner of the subnode
   */
  function setSubnodeOwner(
    bytes32 _node,
    bytes32 _label,
    address _owner,
    bytes32 _pubKeyX,
    bytes32 _pubKeyY
  ) public override authorized(_node) returns (bytes32) {
    bytes32 subnode = keccak256Hash(abi.encodePacked(_node, _label));
    subnode = bytes32(uint256(subnode) % q);
    require(!_exists(subnode), "sub node exists");
    _setOwner(subnode, _owner);
    _setPubKey(subnode, _pubKeyX, _pubKeyY);
    if (_node == 0x0) {
      topLevelDomains[subnode] = true;
      emit TLDAdded(subnode);
    }
    return subnode;
  }

  /**
   * @dev Set the resolver address for the specified node.
   * @param _node The node to update.
   * @param _resolver The address of the resolver.
   */
  function setResolver(bytes32 _node, address _resolver) public override {
    require(records[_node].owner == msg.sender, "unauthorized");
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
  function pubKey(bytes32 node) public view override returns (bytes32, bytes32) {
    return (records[node].pubKeyX, records[node].pubKeyY);
  }

  /**
   * @dev Returns the account Index of the node in the L2
   * @param node The specified node.
   * @return The account index of the specified node
   */
  function accountIndex(bytes32 node) public view override returns (uint32) {
    return records[node].accountIndex;
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
    subnode = bytes32(uint256(subnode) % q);
    return _exists(subnode);
  }

  function keccak256Hash(bytes memory input) public pure returns (bytes32 result) {
    result = keccak256(input);
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

  function _setPubKey(bytes32 _node, bytes32 _pubKeyX, bytes32 _pubKeyY) internal {
    if (_pubKeyX != records[_node].pubKeyX && _pubKeyY != records[_node].pubKeyY) {
      records[_node].pubKeyX = _pubKeyX;
      records[_node].pubKeyY = _pubKeyY;
      emit NewPubKey(_node, _pubKeyX, _pubKeyY);
    }
  }

  function _exists(bytes32 node) internal view returns (bool) {
    return records[node].owner != address(0x0);
  }
}
