// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./Bytes.sol";
import "./Utils.sol";

/// @title zkbnb op tools
library TxTypes {
  /// @notice zkbnb circuit op type
  enum TxType {
    EmptyTx,
    RegisterZNS,
    Deposit,
    DepositNft,
    Transfer,
    Withdraw,
    CreateCollection,
    MintNft,
    TransferNft,
    AtomicMatch,
    CancelOffer,
    WithdrawNft,
    FullExit,
    FullExitNft
  }

  struct RegisterZNS {
    uint8 txType;
    uint32 accountIndex;
    bytes20 accountName;
    bytes32 accountNameHash;
    bytes32 pubKeyX;
    bytes32 pubKeyY;
  }

  // Deposit pubdata
  struct Deposit {
    uint8 txType;
    uint32 accountIndex;
    bytes32 accountNameHash;
    uint16 assetId;
    uint128 amount;
  }

  // Withdraw pubdata
  struct Withdraw {
    uint8 txType;
    uint32 accountIndex;
    address toAddress;
    uint16 assetId;
    uint128 assetAmount;
    uint16 gasFeeAssetId;
    uint16 gasFeeAssetAmount;
  }

  // Withdraw Nft pubdata
  struct WithdrawNft {
    uint8 txType;
    uint32 fromAccountIndex;
    uint32 creatorAccountIndex;
    uint16 creatorTreasuryRate;
    uint40 nftIndex;
    // address nftL1Address;
    address toAddress;
    uint32 gasFeeAccountIndex;
    uint16 gasFeeAssetId;
    uint16 gasFeeAssetAmount;
    bytes32 nftContentHash;
    // uint256 nftL1TokenId;
    bytes32 creatorAccountNameHash;
    uint32 collectionId;
  }

  // full exit pubdata
  struct FullExit {
    uint8 txType;
    uint32 accountIndex;
    uint16 assetId;
    uint128 assetAmount;
    bytes32 accountNameHash;
  }

  // full exit nft pubdata
  struct FullExitNft {
    uint8 txType;
    uint32 accountIndex;
    uint32 creatorAccountIndex;
    uint16 creatorTreasuryRate;
    uint40 nftIndex;
    uint16 collectionId;
    // address nftL1Address;
    bytes32 accountNameHash;
    bytes32 creatorAccountNameHash;
    bytes32 nftContentHash;
    // uint256 nftL1TokenId;
  }

  struct DepositNft {
    uint8 txType;
    uint32 accountIndex;
    uint40 nftIndex;
    // address nftL1Address;
    uint32 creatorAccountIndex;
    uint16 creatorTreasuryRate;
    bytes32 nftContentHash;
    // uint256 nftL1TokenId;
    bytes32 accountNameHash;
    uint16 collectionId;
  }

  // Byte lengths
  uint8 internal constant CHUNK_SIZE = 32;
  // operation type bytes
  uint8 internal constant TX_TYPE_BYTES = 1;

  // 968 bits
  uint256 internal constant PACKED_TX_PUBDATA_BYTES = 121;

  /// Serialize register zns pubdata
  function writeRegisterZNSPubDataForPriorityQueue(RegisterZNS memory _tx) internal pure returns (bytes memory buf) {
    buf = abi.encodePacked(
      uint8(TxType.RegisterZNS),
      _tx.accountIndex,
      _tx.accountName,
      _tx.accountNameHash, // account name hash
      _tx.pubKeyX,
      _tx.pubKeyY
    );
  }

  /// Deserialize register zns pubdata
  function readRegisterZNSPubData(bytes memory _data) internal pure returns (RegisterZNS memory parsed) {
    // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
    uint256 offset = TX_TYPE_BYTES;
    // account index
    (offset, parsed.accountIndex) = Bytes.readUInt32(_data, offset);
    // account name
    (offset, parsed.accountName) = Bytes.readBytes20(_data, offset);
    // account name hash
    (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);
    // public key
    (offset, parsed.pubKeyX) = Bytes.readBytes32(_data, offset);
    (offset, parsed.pubKeyY) = Bytes.readBytes32(_data, offset);

    require(offset == PACKED_TX_PUBDATA_BYTES, "1N");
    return parsed;
  }

  /// @notice Write register zns pubdata for priority queue check.
  function checkRegisterZNSInPriorityQueue(RegisterZNS memory _tx, bytes20 hashedPubData) internal pure returns (bool) {
    return Utils.hashBytesToBytes20(writeRegisterZNSPubDataForPriorityQueue(_tx)) == hashedPubData;
  }

  //    uint256 internal constant PACKED_DEPOSIT_PUBDATA_BYTES = 2 * CHUNK_SIZE;

  /// Serialize deposit pubdata
  function writeDepositPubDataForPriorityQueue(Deposit memory _tx) internal pure returns (bytes memory buf) {
    buf = abi.encodePacked(
      uint8(TxType.Deposit),
      uint32(0),
      _tx.accountNameHash, // account name hash
      _tx.assetId, // asset id
      _tx.amount // state amount
    );
  }

  /// Deserialize deposit pubdata
  function readDepositPubData(bytes memory _data) internal pure returns (Deposit memory parsed) {
    // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
    uint256 offset = TX_TYPE_BYTES;
    // account index
    (offset, parsed.accountIndex) = Bytes.readUInt32(_data, offset);
    // asset id
    (offset, parsed.assetId) = Bytes.readUInt16(_data, offset);
    // state amount
    (offset, parsed.amount) = Bytes.readUInt128(_data, offset);
    // account name
    (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);

    offset += 66;

    require(offset == PACKED_TX_PUBDATA_BYTES, "2N");
    return parsed;
  }

  /// @notice Write deposit pubdata for priority queue check.
  function checkDepositInPriorityQueue(Deposit memory _tx, bytes20 hashedPubData) internal pure returns (bool) {
    return Utils.hashBytesToBytes20(writeDepositPubDataForPriorityQueue(_tx)) == hashedPubData;
  }

  //    uint256 internal constant PACKED_DEPOSIT_NFT_PUBDATA_BYTES = 5 * CHUNK_SIZE;

  /// Serialize deposit pubdata
  function writeDepositNftPubDataForPriorityQueue(DepositNft memory _tx) internal pure returns (bytes memory buf) {
    buf = abi.encodePacked(
      uint8(TxType.DepositNft),
      uint32(0),
      uint40(_tx.nftIndex),
      _tx.creatorAccountIndex,
      _tx.creatorTreasuryRate,
      _tx.nftContentHash,
      _tx.accountNameHash,
      _tx.collectionId
    );
  }

  /// Deserialize deposit pubdata
  function readDepositNftPubData(bytes memory _data) internal pure returns (DepositNft memory parsed) {
    // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
    uint256 offset = TX_TYPE_BYTES;
    // account index
    (offset, parsed.accountIndex) = Bytes.readUInt32(_data, offset);
    // nft index
    (offset, parsed.nftIndex) = Bytes.readUInt40(_data, offset);
    // creator account index
    (offset, parsed.creatorAccountIndex) = Bytes.readUInt32(_data, offset);
    // creator treasury rate
    (offset, parsed.creatorTreasuryRate) = Bytes.readUInt16(_data, offset);
    // collection id
    (offset, parsed.collectionId) = Bytes.readUInt16(_data, offset);
    // nft content hash
    (offset, parsed.nftContentHash) = Bytes.readBytes32(_data, offset);
    // account name
    (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);

    offset += 39;

    require(offset == PACKED_TX_PUBDATA_BYTES, "3N");
    return parsed;
  }

  /// @notice Write deposit pubdata for priority queue check.
  function checkDepositNftInPriorityQueue(DepositNft memory _tx, bytes20 hashedPubData) internal pure returns (bool) {
    return Utils.hashBytesToBytes20(writeDepositNftPubDataForPriorityQueue(_tx)) == hashedPubData;
  }

  //    uint256 internal constant PACKED_WITHDRAW_PUBDATA_BYTES = 2 * CHUNK_SIZE;

  /// Deserialize withdraw pubdata
  function readWithdrawPubData(bytes memory _data) internal pure returns (Withdraw memory parsed) {
    // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
    uint256 offset = TX_TYPE_BYTES;
    // account index
    (offset, parsed.accountIndex) = Bytes.readUInt32(_data, offset);
    // address
    (offset, parsed.toAddress) = Bytes.readAddress(_data, offset);
    // asset id
    (offset, parsed.assetId) = Bytes.readUInt16(_data, offset);
    // amount
    (offset, parsed.assetAmount) = Bytes.readUInt128(_data, offset);
    // gas fee asset id
    (offset, parsed.gasFeeAssetId) = Bytes.readUInt16(_data, offset);
    // gas fee asset amount
    (offset, parsed.gasFeeAssetAmount) = Bytes.readUInt16(_data, offset);
    offset += 74;

    require(offset == PACKED_TX_PUBDATA_BYTES, "4N");
    return parsed;
  }

  //    uint256 internal constant PACKED_WITHDRAWNFT_PUBDATA_BYTES = 6 * CHUNK_SIZE;

  /// Deserialize withdraw pubdata
  function readWithdrawNftPubData(bytes memory _data) internal pure returns (WithdrawNft memory parsed) {
    // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
    uint256 offset = TX_TYPE_BYTES;
    // account index
    (offset, parsed.fromAccountIndex) = Bytes.readUInt32(_data, offset);
    // creator account index
    (offset, parsed.creatorAccountIndex) = Bytes.readUInt32(_data, offset);
    // creator treasury rate
    (offset, parsed.creatorTreasuryRate) = Bytes.readUInt16(_data, offset);
    // nft index
    (offset, parsed.nftIndex) = Bytes.readUInt40(_data, offset);
    // collection id
    (offset, parsed.collectionId) = Bytes.readUInt16(_data, offset);
    // nft l1 address
    (offset, parsed.toAddress) = Bytes.readAddress(_data, offset);
    // gas fee asset id
    (offset, parsed.gasFeeAssetId) = Bytes.readUInt16(_data, offset);
    // gas fee asset amount
    (offset, parsed.gasFeeAssetAmount) = Bytes.readUInt16(_data, offset);
    // nft content hash
    (offset, parsed.nftContentHash) = Bytes.readBytes32(_data, offset);
    // account name hash
    (offset, parsed.creatorAccountNameHash) = Bytes.readBytes32(_data, offset);

    offset += 15;
    require(offset == PACKED_TX_PUBDATA_BYTES, "5N");
    return parsed;
  }

  //    uint256 internal constant PACKED_FULLEXIT_PUBDATA_BYTES = 2 * CHUNK_SIZE;

  /// Serialize full exit pubdata
  function writeFullExitPubDataForPriorityQueue(FullExit memory _tx) internal pure returns (bytes memory buf) {
    buf = abi.encodePacked(
      uint8(TxType.FullExit),
      uint32(0),
      _tx.assetId, // asset id
      uint128(0), // asset amount
      _tx.accountNameHash // account name
    );
  }

  /// Deserialize full exit pubdata
  function readFullExitPubData(bytes memory _data) internal pure returns (FullExit memory parsed) {
    // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
    uint256 offset = TX_TYPE_BYTES;
    // account index
    (offset, parsed.accountIndex) = Bytes.readUInt32(_data, offset);
    // asset id
    (offset, parsed.assetId) = Bytes.readUInt16(_data, offset);
    // asset state amount
    (offset, parsed.assetAmount) = Bytes.readUInt128(_data, offset);
    // account name
    (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);

    offset += 66;

    require(offset == PACKED_TX_PUBDATA_BYTES, "6N");
    return parsed;
  }

  /// @notice Write full exit pubdata for priority queue check.
  function checkFullExitInPriorityQueue(FullExit memory _tx, bytes20 hashedPubData) internal pure returns (bool) {
    return Utils.hashBytesToBytes20(writeFullExitPubDataForPriorityQueue(_tx)) == hashedPubData;
  }

  // uint256 internal constant PACKED_FULLEXITNFT_PUBDATA_BYTES = 6 * CHUNK_SIZE;

  /// Serialize full exit nft pubdata
  function writeFullExitNftPubDataForPriorityQueue(FullExitNft memory _tx) internal pure returns (bytes memory buf) {
    buf = abi.encodePacked(
      uint8(TxType.FullExitNft),
      uint32(0),
      uint32(0),
      uint16(0),
      _tx.nftIndex,
      uint16(0), // collection id
      _tx.accountNameHash, // account name hash
      bytes32(0), // creator account name hash
      bytes32(0) // nft content hash
    );
  }

  /// Deserialize full exit nft pubdata
  function readFullExitNftPubData(bytes memory _data) internal pure returns (FullExitNft memory parsed) {
    // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
    uint256 offset = TX_TYPE_BYTES;
    // account index
    (offset, parsed.accountIndex) = Bytes.readUInt32(_data, offset);
    // creator account index
    (offset, parsed.creatorAccountIndex) = Bytes.readUInt32(_data, offset);
    // creator treasury rate
    (offset, parsed.creatorTreasuryRate) = Bytes.readUInt16(_data, offset);
    // nft index
    (offset, parsed.nftIndex) = Bytes.readUInt40(_data, offset);
    // collection id
    (offset, parsed.collectionId) = Bytes.readUInt16(_data, offset);
    // account name hash
    (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);
    // creator account name hash
    (offset, parsed.creatorAccountNameHash) = Bytes.readBytes32(_data, offset);
    // nft content hash
    (offset, parsed.nftContentHash) = Bytes.readBytes32(_data, offset);

    offset += 7;
    require(offset == PACKED_TX_PUBDATA_BYTES, "7N");
    return parsed;
  }

  /// @notice Write full exit nft pubdata for priority queue check.
  function checkFullExitNftInPriorityQueue(FullExitNft memory _tx, bytes20 hashedPubData) internal pure returns (bool) {
    return Utils.hashBytesToBytes20(writeFullExitNftPubDataForPriorityQueue(_tx)) == hashedPubData;
  }
}
