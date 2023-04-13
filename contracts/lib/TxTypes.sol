// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./Bytes.sol";
import "./Utils.sol";

/// @title zkbnb op tools
library TxTypes {
  /// @notice zkbnb circuit op type
  enum TxType {
    EmptyTx,
    ChangePubKey,
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

  // ChangePubKey pubdata
  struct ChangePubKey {
    uint32 accountIndex;
    bytes32 pubkeyX;
    bytes32 pubkeyY;
    address owner;
    uint32 nonce;
  }

  // Deposit pubdata
  struct Deposit {
    uint32 accountIndex;
    address toAddress;
    uint16 assetId;
    uint128 amount;
  }

  // Withdraw pubdata
  struct Withdraw {
    uint32 accountIndex;
    address toAddress;
    uint16 assetId;
    uint128 assetAmount;
    // uint16 gasFeeAssetId; -- present in pubdata, ignored at serialization
    // uint16 gasFeeAssetAmount; -- present in pubdata, ignored at serialization
  }

  // Withdraw Nft pubdata
  struct WithdrawNft {
    uint32 accountIndex;
    uint32 creatorAccountIndex;
    uint16 creatorTreasuryRate;
    uint40 nftIndex;
    uint16 collectionId;
    // uint16 gasFeeAssetId; -- present in pubdata, ignored at serialization
    // uint16 gasFeeAssetAmount; -- present in pubdata, ignored at serialization
    address toAddress;
    address creatorAddress; // creatorAccountNameHash => creatorAddress
    bytes32 nftContentHash;
    uint8 nftContentType; // New added
  }

  // full exit pubdata
  struct FullExit {
    uint32 accountIndex;
    uint16 assetId;
    uint128 assetAmount;
    address owner;
  }

  // full exit nft pubdata
  struct FullExitNft {
    uint32 accountIndex;
    uint32 creatorAccountIndex;
    uint16 creatorTreasuryRate;
    uint40 nftIndex;
    uint16 collectionId;
    address owner; // accountNameHahsh => owner
    address creatorAddress; // creatorAccountNameHash => creatorAddress
    bytes32 nftContentHash;
    uint8 nftContentType; // New added
  }

  struct DepositNft {
    uint32 accountIndex;
    uint32 creatorAccountIndex;
    uint16 creatorTreasuryRate;
    uint40 nftIndex;
    uint16 collectionId;
    address owner; // accountNameHahsh => owner
    bytes32 nftContentHash;
    uint8 nftContentType; // New added
  }

  // Byte lengths
  uint8 internal constant CHUNK_SIZE = 32;
  // operation type bytes
  uint8 internal constant TX_TYPE_BYTES = 1;

  // 968 bits
  uint256 internal constant PACKED_TX_PUBDATA_BYTES = 121;

  /// Deserialize ChangePubKey pubdata
  function readChangePubKeyPubData(bytes memory _data) internal pure returns (ChangePubKey memory parsed) {
    // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
    uint256 offset = TX_TYPE_BYTES;
    // account index
    (offset, parsed.accountIndex) = Bytes.readUInt32(_data, offset);
    // pubkeyX
    (offset, parsed.pubkeyX) = Bytes.readBytes32(_data, offset);
    // pubkeyY
    (offset, parsed.pubkeyY) = Bytes.readBytes32(_data, offset);
    // owner
    (offset, parsed.owner) = Bytes.readAddress(_data, offset);
    // nonce
    (offset, parsed.nonce) = Bytes.readUInt32(_data, offset);

    // 1 + 4 + 64 + 20 + 4 + x = 121
    // x = 28
    offset += 28;

    require(offset == PACKED_TX_PUBDATA_BYTES, "1N");
    return parsed;
  }

  // uint256 internal constant PACKED_DEPOSIT_PUBDATA_BYTES = 2 * CHUNK_SIZE;

  /// Serialize deposit pubdata
  function writeDepositPubDataForPriorityQueue(Deposit memory _tx) internal pure returns (bytes memory buf) {
    buf = abi.encodePacked(
      uint8(TxType.Deposit),
      uint32(0),
      _tx.toAddress, // to address
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
    // address
    (offset, parsed.toAddress) = Bytes.readAddress(_data, offset);
    // asset id
    (offset, parsed.assetId) = Bytes.readUInt16(_data, offset);
    // state amount
    (offset, parsed.amount) = Bytes.readUInt128(_data, offset);

    // 1 + 4 + 20 + 2 + 16 + x = 121
    // x = 78
    offset += 78;

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
      _tx.creatorAccountIndex,
      _tx.creatorTreasuryRate,
      uint40(_tx.nftIndex),
      _tx.collectionId,
      _tx.owner,
      _tx.nftContentHash,
      _tx.nftContentType
    );
  }

  /// Deserialize deposit pubdata
  function readDepositNftPubData(bytes memory _data) internal pure returns (DepositNft memory parsed) {
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
    // owner
    (offset, parsed.owner) = Bytes.readAddress(_data, offset);
    // nft content hash
    (offset, parsed.nftContentHash) = Bytes.readBytes32(_data, offset);
    // nft content type
    (offset, parsed.nftContentType) = Bytes.readUInt8(_data, offset);

    // 1 + 4 + 4 + 2 + 5 + 2 + 20 + 32 + 1 + x = 121
    // x = 50
    offset += 50;

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
    // (offset, parsed.gasFeeAssetId) = Bytes.readUInt16(_data, offset);
    // gas fee asset amount
    // (offset, parsed.gasFeeAssetAmount) = Bytes.readUInt16(_data, offset);

    // 1 + 4 + 20 + 2 + 16 + x = 121
    // x = 78
    offset += 78;

    require(offset == PACKED_TX_PUBDATA_BYTES, "4N");
    return parsed;
  }

  //    uint256 internal constant PACKED_WITHDRAWNFT_PUBDATA_BYTES = 6 * CHUNK_SIZE;

  /// Deserialize withdraw pubdata
  function readWithdrawNftPubData(bytes memory _data) internal pure returns (WithdrawNft memory parsed) {
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
    // gas fee asset id
    // (offset, parsed.gasFeeAssetId) = Bytes.readUInt16(_data, offset);
    // gas fee asset amount
    // (offset, parsed.gasFeeAssetAmount) = Bytes.readUInt16(_data, offset);
    offset += 4;

    // withdraw to L1 address
    (offset, parsed.toAddress) = Bytes.readAddress(_data, offset);
    // creator address
    (offset, parsed.creatorAddress) = Bytes.readAddress(_data, offset);
    // nft content hash
    (offset, parsed.nftContentHash) = Bytes.readBytes32(_data, offset);
    // nft content type
    (offset, parsed.nftContentType) = Bytes.readUInt8(_data, offset);

    // 1 + 4 + 4 + 2 + 5 + 2 + 2 + 2 + 20 + 20 + 32 + 1 + x = 121
    // x = 26
    offset += 26;
    require(offset == PACKED_TX_PUBDATA_BYTES, "5N");
    return parsed;
  }

  //    uint256 internal constant PACKED_FULLEXIT_PUBDATA_BYTES = 2 * CHUNK_SIZE;

  /// Serialize full exit pubdata
  function writeFullExitPubDataForPriorityQueue(FullExit memory _tx) internal pure returns (bytes memory buf) {
    buf = abi.encodePacked(
      uint8(TxType.FullExit),
      uint32(_tx.accountIndex), // account index
      _tx.assetId, // asset id
      uint128(0), // asset amount
      _tx.owner // owenr
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
    // owner address
    (offset, parsed.owner) = Bytes.readAddress(_data, offset);

    // 1 + 4 + 2 + 16 + 20 + x = 121
    // x = 78
    offset += 78;

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
      _tx.accountIndex, // account index
      uint32(0), // creator account index
      uint16(0), // creator treasory rate
      _tx.nftIndex,
      uint16(0), // collection id
      _tx.owner, //
      address(0), // creator address
      bytes32(0), // nft content hash
      uint8(0) // nft content type
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
    // owner
    (offset, parsed.owner) = Bytes.readAddress(_data, offset);
    // creator address
    (offset, parsed.creatorAddress) = Bytes.readAddress(_data, offset);
    // nft content hash
    (offset, parsed.nftContentHash) = Bytes.readBytes32(_data, offset);
    // nft content type
    (offset, parsed.nftContentType) = Bytes.readUInt8(_data, offset);

    // 1 + 4 + 4 + 2 + 5 + 2 + 20 + 20 + 32 + 1 + x = 121
    offset += 30;
    require(offset == PACKED_TX_PUBDATA_BYTES, "7N");
    return parsed;
  }

  /// @notice Write full exit nft pubdata for priority queue check.
  function checkFullExitNftInPriorityQueue(FullExitNft memory _tx, bytes20 hashedPubData) internal pure returns (bool) {
    return Utils.hashBytesToBytes20(writeFullExitNftPubDataForPriorityQueue(_tx)) == hashedPubData;
  }
}
