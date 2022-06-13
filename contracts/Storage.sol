// SPDX-License-Identifier: MIT OR Apache-2.0
// solhint-disable max-states-count

pragma solidity ^0.7.6;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./Config.sol";
import "./Governance.sol";
import "./ZecreyVerifier.sol";
import "./TxTypes.sol";
import "./AdditionalZecreyLegend.sol";
import "./ZNSController.sol";
import "./resolvers/PublicResolver.sol";
import "./NFTFactory.sol";

/// @title zecrey storage contract
/// @author Zecrey Labs
contract Storage {

    /// @dev Flag indicates that upgrade preparation status is active
    /// @dev Will store false in case of not active upgrade mode
    bool internal upgradePreparationActive;

    /// @dev Upgrade preparation activation timestamp (as seconds since unix epoch)
    /// @dev Will be equal to zero in case of not active upgrade mode
    uint256 internal upgradePreparationActivationTime;

    /// @dev Upgrade notice period, possibly shorten by the security council
    uint256 internal approvedUpgradeNoticePeriod;

    /// @dev Upgrade start timestamp (as seconds since unix epoch)
    /// @dev Will be equal to zero in case of not active upgrade mode
    uint256 internal upgradeStartTimestamp;

    /// @dev Stores boolean flags which means the confirmations of the upgrade for each member of security council
    /// @dev Will store zeroes in case of not active upgrade mode
    mapping(uint256 => bool) internal securityCouncilApproves;
    uint256 internal numberOfApprovalsFromSecurityCouncil;

    // account root
    bytes32 public stateRoot;

    /// @notice Priority Operation container
    /// @member hashedPubData Hashed priority operation public data
    /// @member expirationBlock Expiration block number (ETH block) for this request (must be satisfied before)
    /// @member opType Priority operation type
    struct PriorityTx {
        bytes20 hashedPubData;
        uint64 expirationBlock;
        TxTypes.TxType txType;
    }

    /// @dev Priority Requests mapping (request id - operation)
    /// @dev Contains op type, pubdata and expiration block of unsatisfied requests.
    /// @dev Numbers are in order of requests receiving
    mapping(uint64 => PriorityTx) internal priorityRequests;

    /// @dev Verifier contract. Used to verify block proof and exit proof
    ZecreyVerifier internal verifier;

    /// @dev Governance contract. Contains the governor (the owner) of whole system, validators list, possible tokens list
    Governance internal governance;

    ZNSController internal znsController;
    PublicResolver internal znsResolver;

    uint8 internal constant FILLED_GAS_RESERVE_VALUE = 0xff; // we use it to set gas revert value so slot will not be emptied with 0 balance
    struct PendingBalance {
        uint128 balanceToWithdraw;
        uint8 gasReserveValue; // gives user opportunity to fill storage slot with nonzero value
    }

    /// @dev Root-chain balances (per owner and token id, see packAddressAndAssetId) to withdraw
    mapping(bytes22 => PendingBalance) internal pendingBalances;

    AdditionalZecreyLegend internal additionalZecreyLegend;

    /// @notice Total number of committed blocks i.e. blocks[totalBlocksCommitted] points at the latest committed block
    uint32 public totalBlocksCommitted;
    // total blocks that have been verified
    uint32 public totalBlocksVerified;

    /// @dev First open priority request id
    uint64 public firstPriorityRequestId;

    /// @dev Total number of requests
    uint64 public totalOpenPriorityRequests;

    /// @dev Total number of committed requests.
    /// @dev Used in checks: if the request matches the operation on Rollup contract and if provided number of requests is not too big
    uint64 internal totalCommittedPriorityRequests;

    /// @notice Packs address and token id into single word to use as a key in balances mapping
    function packAddressAndAssetId(address _address, uint16 _assetId) internal pure returns (bytes22) {
        return bytes22((uint176(_address) | (uint176(_assetId) << 160)));
    }

    struct StoredBlockInfo {
        uint32 blockNumber;
        uint64 priorityOperations;
        bytes32 pendingOnchainOperationsHash;
        uint256 timestamp;
        bytes32 stateRoot;
        bytes32 commitment;
    }

    function hashStoredBlockInfo(StoredBlockInfo memory _block) internal pure returns (bytes32) {
        return keccak256(abi.encode(_block));
    }

    /// @dev Stored hashed StoredBlockInfo for some block number
    mapping(uint32 => bytes32) public storedBlockHashes;

    /// @dev Flag indicates that exodus (mass exit) mode is triggered
    /// @dev Once it was raised, it can not be cleared again, and all users must exit
    bool public desertMode;

    /// @dev Flag indicates that a user has exited in the exodus mode certain token balance (per account id and tokenId)
    mapping(uint32 => mapping(uint32 => bool)) internal performedDesert;

    /// @notice Checks that current state not is exodus mode
    function requireActive() internal view {
        require(!desertMode, "L");
        // desert mode activated
    }

    /// @notice All token pairs in Zecrey Network

    /// @notice Total number of tokens pairs registered in the network (start from 1)
    uint16 public totalTokenPairs;
    mapping(uint16 => mapping(uint16 => bool)) isTokenPairExist;
    mapping(uint16 => mapping(uint16 => uint16)) tokenPairs;


    mapping(uint40 => TxTypes.WithdrawNft) internal pendingWithdrawnNFTs;

    struct L2NftInfo {
        uint40 nftIndex;
        uint32 creatorAccountIndex;
        uint16 creatorTreasuryRate;
        bytes32 nftContentHash;
        uint16 collectionId;
    }

    mapping(bytes32 => L2NftInfo) internal l2Nfts;

    /// @notice NFTFactories registered.
    /// @dev creator accountNameHash => CollectionId => NFTFactory
    mapping(bytes32 => mapping(uint32 => address)) public nftFactories;

    /// @notice Address which will be used if no factories is specified.
    address public defaultNFTFactory;

}
