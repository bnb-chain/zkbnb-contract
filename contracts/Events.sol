// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

import "./Upgradeable.sol";
import "./TxTypes.sol";

/// @title Zkbas events
/// @author Zkbas Team
interface Events {
    /// @notice Event emitted when a block is committed
    event BlockCommit(uint32 blockNumber);

    /// @notice Event emitted when a block is verified
    event BlockVerification(uint32 blockNumber);

    /// @notice Event emitted when user funds are withdrawn from the Zkbas state and contract
    event Withdrawal(uint16 assetId, uint128 amount);

    /// @notice Event emitted when user funds are deposited to the zkbas account
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

    event RegisterZNS(
        string name,
        bytes32 nameHash,
        address owner,
        bytes32 zkbasPubKeyX,
        bytes32 zkbasPubKeyY,
        uint32 accountIndex
    );

    /// @notice Deposit committed event.
    event DepositCommit(
        uint32 indexed zkbasBlockNumber,
        uint32 indexed accountIndex,
        bytes32 accountName,
        uint16 indexed assetId,
        uint128 amount
    );

    /// @notice Full exit committed event.
    event FullExitCommit(
        uint32 indexed zkbasBlockId,
        uint32 indexed accountId,
        address owner,
        uint16 indexed tokenId,
        uint128 amount
    );

    /// @notice Notice period changed
    event NoticePeriodChange(uint256 newNoticePeriod);

    /// @notice NFT deposit event.
    event DepositNft(
        bytes32 accountNameHash,
        bytes32 nftContentHash,
        address tokenAddress,
        uint256 nftTokenId,
        uint16 creatorTreasuryRate
    );

    /// @notice NFT withdraw event.
    event WithdrawNft (
        uint32 accountIndex,
        address nftL1Address,
        address toAddress,
        uint256 nftL1TokenId
    );

    /// @notice Event emitted when user NFT is withdrawn from the zkSync state but not from contract
    event WithdrawalNFTPending(uint40 indexed nftIndex);

    /// @notice Token pair created event.
    event CreateTokenPair (
        uint16 pairIndex,
        uint16 asset0Id,
        uint16 asset1Id,
        uint16 feeRate,
        uint32 treasuryAccountIndex,
        uint16 treasuryRate
    );

    /// @notice Update token pair event.
    event UpdateTokenPair (
        uint16 pairIndex,
        uint16 feeRate,
        uint32 treasuryAccountIndex,
        uint16 treasuryRate
    );

    /// @notice Default NFTFactory changed
    event NewDefaultNFTFactory(address indexed factory);

    /// @notice New NFT Factory
    event NewNFTFactory(bytes32 indexed _creatorAccountNameHash, uint32 _collectionId, address _factoryAddress);
}

/// @title Upgrade events
/// @author Zkbas Team
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
