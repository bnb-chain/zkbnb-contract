// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../lib/TxTypes.sol";
import "../interfaces/INFTFactory.sol";
import "../ZkBNB.sol";
import "../Storage.sol";

/// @title BNBPaymentFallback - A contract that has a fallback to accept BNB payments
/// An example of this contract is Gnosis Safe Proxy
contract BNBReceivable {
  event BNBReceived(address indexed sender, uint256 value);

  /// @dev Fallback function accepts BNB transactions.
  receive() external payable {
    emit BNBReceived(msg.sender, msg.value);
  }
}
