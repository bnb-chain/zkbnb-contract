// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

import "./StringUtils.sol";

contract ZNSRegistry {

    using StringUtils for string;

    // @dev Require the msg.sender is the owner of this nameHash
    modifier authorized(bytes32 nameHash) {
        address owner = ZNSRecords[nameHash].owner;
        require(owner == msg.sender, "unauthorized");
        _;
    }

    struct Record {
        // The owner of a record may:
        // 1. Transfer ownership of the name to another address
        // 2. Change the ownership of sub account name
        // 3. Change the L2 owner of this account name
        address owner;
        bytes32 L2Owner;
    }

    mapping(bytes32 => Record) ZNSRecords; // nameHash => Record
    mapping(bytes32 => bytes32) ZNSL2Mapper; // L2Owner => nameHash

    /**
     * @dev Constructs a new registry.
     */
    constructor() {
        ZNSRecords[0x0].owner = msg.sender;
        ZNSRecords[0x0].L2Owner = 0x0;
    }

    /**
     * @dev Register a new name if it not exists.
     * @param name The plaintext of account name to register
     * @param owner The address to receive this name
     * @param ownerL2Account The L2 address to receive this name
     */
    function register(string calldata name, address owner, bytes32 ownerL2Account) external {
        // Check if this name is valid
        require(_valid(name), "invalid name");

        bytes32 nameHash = keccak256(bytes(name));

        // This name should not be registered before
        require(!_exists(nameHash), "account name existed");
        // This owner should not own any name in L2.
        require(_L2AccountValid(ownerL2Account), "L2 account has owned an account name");

        _setOwner(nameHash, owner, ownerL2Account);

        emit ZNSRegister(name, nameHash, owner, ownerL2Account);
    }

    /**
     * @dev Register a sub name under a existed name for a address, if the sub name not exists.
     * @param name The plaintext of account name to register
     * @param parentNameHash The hashed name of the parent name who owns this sub name
     * @param owner The address to receive this name
     * @param ownerL2Account The L2 address to receive this name
     */
    function registerSubName(string calldata name, bytes32 parentNameHash, address owner, bytes32 ownerL2Account) external authorized(parentNameHash) {
        // Check if this name is valid
        require(_valid(name), "invalid name");
        // This father name should be registered before
        require(_exists(parentNameHash), "parent account name not existed");

        bytes32 nameHash = keccak256(bytes(name));
        // new child node is a hash of parentNameHash and this nameHash
        bytes32 childNameHash = keccak256(abi.encodePacked(parentNameHash, nameHash));

        // This sub name should not be registered before
        require(!_exists(childNameHash), "account name existed");
        // This owner should not own any name in L2.
        require(_L2AccountValid(ownerL2Account), "L2 account has owned an account name");

        _setOwner(childNameHash, owner, ownerL2Account);

        emit ZNSRegisterSubName(name, childNameHash, parentNameHash, owner, ownerL2Account);
    }


    /**
     * @dev Transfer a name to another account with its L2 account
     * @param nameHash The hashed specified name
     * @param to The mew address to receive this name
     * @param toL2Account The new L2 address to receive this name
     */
    function transfer(bytes32 nameHash, address to, bytes32 toL2Account) external authorized(nameHash) {
        // This toL2Account should not owned any name in L2
        require(_L2AccountValid(toL2Account), "L2 account has owned an account name");

        // Get original owner of this name
        address from = ZNSRecords[nameHash].owner;
        bytes32 fromL2Account = ZNSRecords[nameHash].L2Owner;
        require(from == msg.sender, "unauthorized");

        _setOwner(nameHash, to, toL2Account);

        emit ZNSTransfer(nameHash, from, fromL2Account, to, toL2Account);
    }

    /**
     * @dev Transfer a name to another account in L2, this operation must be sent by this name's owner
     * @param nameHash The hashed specified name
     * @param toL2Account The new L2 address to receive this name
     */
    function transferL2(bytes32 nameHash, bytes32 toL2Account) external authorized(nameHash) {
        // This toL2Account should not owned any name in L2.
        require(_L2AccountValid(toL2Account), "L2 account has owned an account name");

        // Get original owner of this name
        address addr = ZNSRecords[nameHash].owner;
        bytes32 fromL2Account = ZNSRecords[nameHash].L2Owner;
        require(addr == msg.sender, "unauthorized");

        _setL2Owner(nameHash, toL2Account);

        emit ZNSL2Transfer(nameHash, addr, fromL2Account, toL2Account);
    }

    /**
     * @dev Returns whether a record has been imported to the registry.
     * @param nameHash The nameHash of specified account name
     * @return bool If record exists
     */
    function recordExists(bytes32 nameHash) external view returns (bool) {
        return _exists(nameHash);
    }

    /**
     * @dev Returns the address that owns the specified name.
     * @param nameHash The hashed specified name.
     * @return address of the owner.
     */
    function getOwner(bytes32 nameHash) external view returns (address) {
        address owner = ZNSRecords[nameHash].owner;
        if (owner == address(this)) {
            return address(0x0);
        }
        return owner;
    }

    /**
     * @dev Returns address of owner in L2 who owns the specified name.
     * @param nameHash The hashed specified name.
     * @return bytes32 Public key of the owner in L2
     */
    function getL2Owner(bytes32 nameHash) external view returns (bytes32) {
        return ZNSRecords[nameHash].L2Owner;
    }

    function _valid(string memory name) internal pure returns (bool) {
        return _validCharSet(name) && _validLength(name);
    }

    function _validCharSet(string memory name) internal pure returns (bool) {
        return name.charsetValid();
    }

    function _validLength(string memory name) internal pure returns (bool) {
        return name.strlen() >= 3 && name.strlen() <= 32;
    }

    function _setOwner(bytes32 nameHash, address to, bytes32 toL2Account) internal {
        ZNSRecords[nameHash].owner = to;
        ZNSRecords[nameHash].L2Owner = toL2Account;

        ZNSL2Mapper[toL2Account] = nameHash;

        emit ZNSNewOwner(nameHash, to, toL2Account);
    }

    function _setL2Owner(bytes32 nameHash, bytes32 toL2Account) internal {
        ZNSRecords[nameHash].L2Owner = toL2Account;

        ZNSL2Mapper[toL2Account] = nameHash;

        emit ZNSNewL2Owner(nameHash, toL2Account);
    }

    function _L2AccountValid(bytes32 L2Account) internal view returns (bool) {
        return ZNSL2Mapper[L2Account] == 0x0;
    }

    function _exists(bytes32 nameHash) internal view returns (bool) {
        return ZNSRecords[nameHash].owner != address(0x0);
    }

    // Notify a new owner of one name.
    event ZNSNewOwner(bytes32 nameHash, address owner, bytes32 L2Owner);

    // Notify a new L2 owner of one name.
    event ZNSNewL2Owner(bytes32 nameHash, bytes32 L2Owner);

    // Notify a new name is registered to a account with its account public key in L2.
    event ZNSRegister(string name, bytes32 nameHash, address to, bytes32 toL2Account);

    // Notify a sub account name is registered to a account with its account public key in L2.
    event ZNSRegisterSubName(string name, bytes32 childNameHash, bytes32 parentNameHash, address to, bytes32 toL2Account);

    // Notify one name is transferred from one account to another.
    event ZNSTransfer(bytes32 nameHash, address from, bytes32 fromL2Account, address to, bytes32 toL2Account);

    // Notify one name is transferred from one L2 account to another L2 account.
    event ZNSL2Transfer(bytes32 name, address owner, bytes32 from, bytes32 to);
}
