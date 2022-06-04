// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

/// @title Zecrey configuration constants
/// @author Zecrey Team
contract Config {

    /// @dev Configurable notice period
    uint256 public constant UPGRADE_NOTICE_PERIOD = 4 weeks;
    /// @dev Shortest notice period
    uint256 public constant SHORTEST_UPGRADE_NOTICE_PERIOD = 0;

    uint256 public constant SECURITY_COUNCIL_MEMBERS_NUMBER = 3;

    /// @dev ERC20 tokens and ETH withdrawals gas limit, used only for complete withdrawals
    uint256 public constant WITHDRAWAL_GAS_LIMIT = 100000;
    /// @dev NFT withdrawals gas limit, used only for complete withdrawals
    uint256 internal constant WITHDRAWAL_NFT_GAS_LIMIT = 300000;
    /// @dev Max amount of tokens registered in the network (excluding ETH, which is hardcoded as tokenId = 0)
    uint16 public constant MAX_AMOUNT_OF_REGISTERED_ASSETS = 2 ** 16 - 1;

    /// @dev Max account id that could be registered in the network
    uint32 public constant MAX_ACCOUNT_INDEX = 2 ** 32 - 1;

    /// @dev Max deposit of ERC20 token that is possible to deposit
    uint128 public constant MAX_DEPOSIT_AMOUNT = 2 ** 104 - 1;

    /// @dev Expiration delta for priority request to be satisfied (in seconds)
    /// @dev NOTE: Priority expiration should be > (EXPECT_VERIFICATION_IN * BLOCK_PERIOD)
    /// @dev otherwise incorrect block with priority op could not be reverted.
    uint256 internal constant PRIORITY_EXPIRATION_PERIOD = 7 days;

    /// @dev Expected average period of block creation
    uint256 internal constant BLOCK_PERIOD = 15 seconds;

    /// @dev Expiration delta for priority request to be satisfied (in seconds)
    /// @dev NOTE: Priority expiration should be > (EXPECT_VERIFICATION_IN * BLOCK_PERIOD)
    /// @dev otherwise incorrect block with priority op could not be reverted.
    uint256 internal constant PRIORITY_EXPIRATION = PRIORITY_EXPIRATION_PERIOD / BLOCK_PERIOD;

    uint32 public constant SPECIAL_ACCOUNT_ID = 0;
    address public constant SPECIAL_ACCOUNT_ADDRESS = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);

    uint32 public constant MAX_FUNGIBLE_ASSET_ID = (2 ** 32) - 1;

    uint256 public constant CHUNK_SIZE = 6 * 32;

    uint40 public constant MAX_NFT_INDEX = (2 ** 40) - 1;

}
