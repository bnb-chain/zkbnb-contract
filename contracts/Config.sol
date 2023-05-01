// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @title ZkBNB configuration constants
/// @author ZkBNB Team
contract Config {
  /// @dev BEP20 tokens and BNB withdrawals gas limit, used only for complete withdrawals
  uint256 public constant WITHDRAWAL_GAS_LIMIT = 100000;
  /// @dev NFT withdrawals gas limit, used only for complete withdrawals
  uint256 internal constant WITHDRAWAL_NFT_GAS_LIMIT = 300000;
  /// @dev Pending NFT withdrawals gas limit, used only for user to call for pending NFT withdrawals
  uint256 internal constant WITHDRAWAL_PENDING_NFT_GAS_LIMIT = 2000000;
  /// @dev Max amount of tokens registered in the network (excluding BNB, which is hardcoded as tokenId = 0)
  uint16 public constant MAX_AMOUNT_OF_REGISTERED_ASSETS = 2 ** 16 - 2;

  /// @dev Max account id that could be registered in the network
  uint32 public constant MAX_ACCOUNT_INDEX = 2 ** 32 - 2;

  /// @dev Max deposit of BEP20 token that is possible to deposit
  uint128 public constant MAX_DEPOSIT_AMOUNT = 2 ** 104 - 1;

  /// @dev Expiration delta for priority request to be satisfied (in seconds)
  /// @dev NOTE: Priority expiration should be > (EXPECT_VERIFICATION_IN * BLOCK_PERIOD)
  /// @dev otherwise incorrect block with priority op could not be reverted.
  uint256 internal constant PRIORITY_EXPIRATION_PERIOD = 7 days;

  /// @dev Expected average period of block creation
  uint256 internal constant BLOCK_PERIOD = 3 seconds;

  /// @dev Expiration delta for priority request to be satisfied (in seconds)
  /// @dev NOTE: Priority expiration should be > (EXPECT_VERIFICATION_IN * BLOCK_PERIOD)
  /// @dev otherwise incorrect block with priority op could not be reverted.
  uint256 internal constant PRIORITY_EXPIRATION = PRIORITY_EXPIRATION_PERIOD / BLOCK_PERIOD;

  uint32 public constant SPECIAL_ACCOUNT_ID = 0;

  uint40 public constant MAX_NFT_INDEX = (2 ** 40) - 2;
}
