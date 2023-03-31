// SPDX-License-Identifier: Apache-2.0
// solhint-disable max-states-count

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./Config.sol";
import "./Governance.sol";
import "./ZkBNBVerifier.sol";
import "./lib/TxTypes.sol";
import "./AdditionalZkBNB.sol";
import "./interfaces/INFTFactory.sol";
import "./DesertVerifier.sol";

/// @title zkbnb storage contract
/// @author ZkBNB Labs
contract Storage {
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

  /// @dev Verifier contract. Used to verify block proof
  ZkBNBVerifier internal verifier;

  /// @dev Desert verifier contract. Used to verify exit proof
  DesertVerifier internal desertVerifier;

  /// @dev Governance contract. Contains the governor (the owner) of whole system, validators list, possible tokens list
  Governance internal governance;

  uint8 internal constant FILLED_GAS_RESERVE_VALUE = 0xff; // we use it to set gas revert value so slot will not be emptied with 0 balance
  struct PendingBalance {
    uint128 balanceToWithdraw;
    uint8 gasReserveValue; // gives user opportunity to fill storage slot with nonzero value
  }

  /// @dev Root-chain balances (per owner and token id, see packAddressAndAssetId) to withdraw
  mapping(bytes22 => PendingBalance) internal pendingBalances;

  AdditionalZkBNB internal additionalZkBNB;

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
    return bytes22((uint176(uint160(_address)) | (uint176(_assetId) << 160)));
  }

  struct StoredBlockInfo {
    uint16 blockSize;
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

  /// @dev Flag indicates that desert (mass exit) mode is triggered
  /// @dev Once it was raised, it can not be cleared again, and all users must exit
  bool public desertMode;

  /// @dev Flag indicates that a user has exited in the desert mode certain token balance (per account id and tokenId)
  mapping(uint32 => mapping(uint32 => bool)) internal performedDesert;

  /// @notice Checks that current state not is desert mode
  modifier onlyActive() {
    require(!desertMode, "L");
    // desert mode activated
    _;
  }

  mapping(uint40 => TxTypes.WithdrawNft) internal pendingWithdrawnNFTs;

  struct L2NftInfo {
    uint40 nftIndex;
    uint32 creatorAccountIndex;
    uint16 creatorTreasuryRate;
    bytes32 nftContentHash;
    uint8 nftContentType;
    uint16 collectionId;
  }

  mapping(bytes32 => L2NftInfo) internal mintedNfts;
}
