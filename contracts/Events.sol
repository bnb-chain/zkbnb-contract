// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

import "./Upgradeable.sol";
import "./TxTypes.sol";

/// @title Zecrey events
/// @author Zecrey Team
interface Events {
    /// @notice Event emitted when a block is committed
    event BlockCommit(uint32 blockNumber);

    /// @notice Event emitted when a block is verified
    event BlockVerification(uint32 blockNumber);

    event BlockExecution(uint32 blockNumber);

    /// @notice Event emitted when user funds are withdrawn from the Zecrey state and contract
    event Withdrawal(uint16 assetId, uint128 amount);

    /// @notice Event emitted when user funds are withdrawn from the Zecrey state but not from contract
    event WithdrawalPending(uint16 assetId, uint128 amount);

    /// @notice Event emitted when user funds are deposited to the zecrey account
    event Deposit(uint16 assetId, bytes32 accountName, uint128 amount);

    /// @notice Event emitted when blocks are reverted
    event BlocksRevert(uint32 totalBlocksVerified, uint32 totalBlocksCommitted);

    /// @notice Exodus mode entered event
    event DesertMode();

    /// @notice New priority request event. Emitted when a request is placed into mapping
    event NewPriorityRequest(
        address sender,
        uint64 serialId,
        TxTypes.TxType txType,
        bytes pubData,
        uint256 expirationBlock
    );

    /// @notice Deposit committed event.
    event DepositCommit(
        uint32 indexed zecreyBlockNumber,
        uint32 indexed accountIndex,
        bytes32 accountName,
        uint16 indexed assetId,
        uint128 amount
    );

    /// @notice Full exit committed event.
    event FullExitCommit(
        uint32 indexed zecreyBlockId,
        uint32 indexed accountId,
        address owner,
        uint16 indexed tokenId,
        uint128 amount
    );

    /// @notice Notice period changed
    event NoticePeriodChange(uint256 newNoticePeriod);

    /// @notice NFT deposit event.
    event DepositERC721(
        bytes32 accountNameHash,
        address tokenAddress,
        uint256 nftTokenId
    );

    /// @notice NFT withdraw event.
    event WithdrawNFT (
        address sender,
        bytes32 accountName,
        address tokenAddress,
        address minter,
        uint8 nftType,
        uint256 nftID,
        uint amount
    );
}

/// @title Upgrade events
/// @author Matter Labs
interface UpgradeEvents {
    /// @notice Event emitted when new upgradeable contract is added to upgrade gatekeeper's list of managed contracts
    event NewUpgradable(uint256 indexed versionId, address indexed upgradeable);

    /// @notice Upgrade mode enter event
    event NoticePeriodStart(
        uint256 indexed versionId,
        address[] newTargets,
        uint256 noticePeriod // notice period (in seconds)
    );

    /// @notice Upgrade mode cancel event
    event UpgradeCancel(uint256 indexed versionId);

    /// @notice Upgrade mode preparation status event
    event PreparationStart(uint256 indexed versionId);

    /// @notice Upgrade mode complete event
    event UpgradeComplete(uint256 indexed versionId, address[] newTargets);
}
