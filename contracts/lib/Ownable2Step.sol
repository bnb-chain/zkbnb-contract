// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IOwnable2Step.sol";

/**
 * @title The Ownable2Step contract
 * @notice A contract with helpers for basic contract ownership.
 */
contract Ownable2Step is IOwnable2Step {
  address private _owner;
  address private _pendingOwner;

  event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  constructor(address __owner) {
    require(__owner != address(0), "Cannot set owner to zero");

    _owner = __owner;
  }

  /**
   * @notice Get the current owner
   */
  function owner() public view override returns (address) {
    return _owner;
  }

  /**
   * @dev Returns the address of the pending owner.
   */
  function pendingOwner() public view virtual returns (address) {
    return _pendingOwner;
  }

  /**
   * @notice Allows an owner to begin transferring ownership to a new address,
   * pending.
   */
  function transferOwnership(address to) public override onlyOwner {
    _transferOwnership(to);
  }

  /**
   * @notice Allows an ownership transfer to be completed by the recipient.
   */
  function acceptOwnership() external override {
    require(msg.sender == _pendingOwner, "Must be proposed owner");

    address oldOwner = _owner;
    _owner = msg.sender;
    _pendingOwner = address(0);

    emit OwnershipTransferred(oldOwner, msg.sender);
  }

  /**
   * @notice validate, transfer ownership, and emit relevant events
   */
  function _transferOwnership(address to) private {
    require(to != msg.sender, "Cannot transfer to self");

    _pendingOwner = to;

    emit OwnershipTransferStarted(_owner, to);
  }

  /**
   * @notice Reverts if called by anyone other than the contract owner.
   */
  modifier onlyOwner() {
    require(msg.sender == _owner, "Only callable by owner");
    _;
  }
}
