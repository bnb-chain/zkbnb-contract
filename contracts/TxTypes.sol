// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

pragma experimental ABIEncoderV2;

import "./Bytes.sol";
import "./Utils.sol";

/// @title zecrey op tools
library TxTypes {

    /// @notice zecrey circuit op type
    enum TxType {
        EmptyTx,
        RegisterZNS,
        CreatePair,
        UpdatePairRate,
        Deposit,
        DepositNft,
        Transfer,
        Swap,
        AddLiquidity,
        RemoveLiquidity,
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

    // Byte lengths
    uint8 internal constant CHUNK_SIZE = 32;
    // operation type bytes
    uint8 internal constant TX_TYPE_BYTES = 1;
    // nft type
    uint8 internal constant NFT_TYPE_BYTES = 1;
    // token pair id bytes, max 2**16
    uint8 internal constant TOKEN_PAIR_ID_BYTES = 2;
    // asset id bytes, max 2**16
    uint8 internal constant ASSET_ID_BYTES = 2;
    // pub key bytes
    uint8 internal constant PUBKEY_BYTES = 32;
    // state amount bytes
    uint8 internal constant STATE_AMOUNT_BYTES = 16;
    // account name bytes
    uint8 internal constant ACCOUNT_NAME_BYTES = 32;
    // account name hash bytes
    uint8 internal constant ACCOUNT_NAME_HASH_BYTES = 32;
    // packed amount bytes
    uint8 internal constant PACKED_AMOUNT_BYTES = 5;
    // packed fee bytes
    uint8 internal constant PACKED_FEE_AMOUNT_BYTES = 2;
    // account index bytes, max 2**32
    uint8 internal constant ACCOUNT_INDEX_BYTES = 4;
    // nft amount bytes
    uint8 internal constant NFT_AMOUNT_BYTES = 4;
    // address bytes
    uint8 internal constant ADDRESS_BYTES = 20;
    // nft asset id
    uint8 internal constant NFT_INDEX_BYTES = 5;
    // nft token id bytes
    uint8 internal constant NFT_TOKEN_ID_BYTES = 32;
    // nft content hash bytes
    uint8 internal constant NFT_CONTENT_HASH_BYTES = 32;
    // creator treasury rate
    uint8 internal constant CREATOR_TREASURY_RATE_BYTES = 2;
    // fee rate bytes
    uint8 internal constant RATE_BYTES = 2;

    struct RegisterZNS {
        uint8 txType;
        uint32 accountIndex;
        bytes32 accountName;
        bytes32 accountNameHash;
        bytes32 pubKey;
    }

    uint256 internal constant PACKED_REGISTERZNS_PUBDATA_BYTES = 1 * CHUNK_SIZE;

    /// Serialize register zns pubdata
    function writeRegisterZNSPubDataForPriorityQueue(RegisterZNS memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
            uint32(0),
            _tx.accountName,
            _tx.accountNameHash, // account name hash
            _tx.pubKey
        );
    }

    /// Deserialize register zns pubdata
    function readRegisterZNSPubData(bytes memory _data) internal pure returns (RegisterZNS memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;
        // account index
        (offset, parsed.accountIndex) = Bytes.readUInt32(_data, offset);
        // empty data
        offset += 27;
        // account name
        (offset, parsed.accountName) = Bytes.readBytes32(_data, offset);
        // account name hash
        (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);
        // public key
        (offset, parsed.pubKey) = Bytes.readBytes32(_data, offset);

        require(offset == PACKED_REGISTERZNS_PUBDATA_BYTES, "N");
        return parsed;
    }

    /// @notice Write register zns pubdata for priority queue check.
    function checkRegisterZNSInPriorityQueue(RegisterZNS memory _tx, bytes20 hashedPubData) internal pure returns (bool) {
        return Utils.hashBytesToBytes20(writeRegisterZNSPubDataForPriorityQueue(_tx)) == hashedPubData;
    }

    struct CreatePair {
        uint8 txType;
        uint16 pairIndex;
        uint16 assetAId;
        uint16 assetBId;
        uint16 feeRate;
        uint32 treasuryAccountIndex;
        uint16 treasuryRate;
    }

    uint256 internal constant PACKED_CREATEPAIR_PUBDATA_BYTES = 1 * CHUNK_SIZE;

    function writeCreatePairPubDataForPriorityQueue(CreatePair memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
            _tx.pairIndex,
            _tx.assetAId,
            _tx.assetBId,
            _tx.feeRate,
            _tx.treasuryAccountIndex,
            _tx.treasuryRate
        );
    }

    /// Deserialize create pair pubdata
    function readCreatePairPubData(bytes memory _data) internal pure returns (CreatePair memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;

        (offset, parsed.pairIndex) = Bytes.readUInt16(_data, offset);
        (offset, parsed.assetAId) = Bytes.readUInt16(_data, offset);
        (offset, parsed.assetBId) = Bytes.readUInt16(_data, offset);
        (offset, parsed.feeRate) = Bytes.readUInt16(_data, offset);
        (offset, parsed.treasuryAccountIndex) = Bytes.readUInt32(_data, offset);
        (offset, parsed.treasuryRate) = Bytes.readUInt16(_data, offset);
        offset += 17;

        require(offset == PACKED_CREATEPAIR_PUBDATA_BYTES, "N");
        return parsed;
    }

    /// @notice Write create pair pubdata for priority queue check.
    function checkCreatePairInPriorityQueue(CreatePair memory _tx, bytes20 hashedPubData) internal pure returns (bool) {
        return Utils.hashBytesToBytes20(writeCreatePairPubDataForPriorityQueue(_tx)) == hashedPubData;
    }

    struct UpdatePairRate {
        uint8 txType;
        uint16 pairIndex;
        uint16 feeRate;
        uint32 treasuryAccountIndex;
        uint16 treasuryRate;
    }

    uint256 internal constant PACKED_UPDATEPAIR_PUBDATA_BYTES = 1 * CHUNK_SIZE;

    function writeUpdatePairRatePubDataForPriorityQueue(UpdatePairRate memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
            _tx.pairIndex,
            _tx.feeRate,
            _tx.treasuryAccountIndex,
            _tx.treasuryRate
        );
    }

    /// Deserialize update pair pubdata
    function readUpdatePairRatePubData(bytes memory _data) internal pure returns (UpdatePairRate memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;

        (offset, parsed.pairIndex) = Bytes.readUInt16(_data, offset);
        (offset, parsed.feeRate) = Bytes.readUInt16(_data, offset);
        (offset, parsed.treasuryAccountIndex) = Bytes.readUInt32(_data, offset);
        (offset, parsed.treasuryRate) = Bytes.readUInt16(_data, offset);

        offset += 21;

        require(offset == PACKED_UPDATEPAIR_PUBDATA_BYTES, "N");
        return parsed;
    }

    /// @notice Write update pair pubdata for priority queue check.
    function checkUpdatePairRateInPriorityQueue(UpdatePairRate memory _tx, bytes20 hashedPubData) internal pure returns (bool) {
        return Utils.hashBytesToBytes20(writeUpdatePairRatePubDataForPriorityQueue(_tx)) == hashedPubData;
    }

    // Deposit pubdata
    struct Deposit {
        uint8 txType;
        uint32 accountIndex;
        bytes32 accountNameHash;
        uint16 assetId;
        uint128 amount;
    }

    uint256 internal constant PACKED_DEPOSIT_PUBDATA_BYTES = 2 * CHUNK_SIZE;

    /// Serialize deposit pubdata
    function writeDepositPubDataForPriorityQueue(Deposit memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
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
        // empty data
        offset += 9;
        // account name
        (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);

        require(offset == PACKED_DEPOSIT_PUBDATA_BYTES, "N");
        return parsed;
    }

    /// @notice Write deposit pubdata for priority queue check.
    function checkDepositInPriorityQueue(Deposit memory _tx, bytes20 hashedPubData) internal pure returns (bool) {
        return Utils.hashBytesToBytes20(writeDepositPubDataForPriorityQueue(_tx)) == hashedPubData;
    }

    struct DepositNft {
        uint8 txType;
        uint32 accountIndex;
        uint40 nftIndex;
        address nftL1Address;
        uint16 creatorTreasuryRate;
        bytes32 nftContentHash;
        uint256 nftL1TokenId;
        bytes32 accountNameHash;
    }

    uint256 internal constant PACKED_DEPOSIT_NFT_PUBDATA_BYTES = 5 * CHUNK_SIZE;

    /// Serialize deposit pubdata
    function writeDepositNftPubDataForPriorityQueue(DepositNft memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
            uint32(0),
            uint40(0),
            _tx.nftL1Address, // token address
            _tx.creatorTreasuryRate,
            bytes32(0),
            _tx.nftL1TokenId, // nft token id
            _tx.accountNameHash // account name hash
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
        // nft l1 address
        (offset, parsed.nftL1Address) = Bytes.readAddress(_data, offset);
        // empty data
        offset += 2;
        // creator treasury rate
        (offset, parsed.creatorTreasuryRate) = Bytes.readUInt16(_data, offset);
        // empty data
        offset += 30;
        // nft content hash
        (offset, parsed.nftContentHash) = Bytes.readBytes32(_data, offset);
        // nft l1 token id
        (offset, parsed.nftL1TokenId) = Bytes.readUInt256(_data, offset);
        // account name
        (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);

        require(offset == PACKED_DEPOSIT_NFT_PUBDATA_BYTES, "N");
        return parsed;
    }

    /// @notice Write deposit pubdata for priority queue check.
    function checkDepositNftInPriorityQueue(DepositNft memory _tx, bytes20 hashedPubData) internal pure returns (bool) {
        return Utils.hashBytesToBytes20(writeDepositNftPubDataForPriorityQueue(_tx)) == hashedPubData;
    }

    // Withdraw pubdata
    struct Withdraw {
        uint8 txType;
        uint32 accountIndex;
        address toAddress;
        uint16 assetId;
        uint128 assetAmount;
        uint32 gasFeeAccountIndex;
        uint16 gasFeeAssetId;
        uint16 gasFeeAssetAmount;
    }

    uint256 internal constant PACKED_WITHDRAW_PUBDATA_BYTES = 2 * CHUNK_SIZE;

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
        // empty data
        offset += 5;
        // amount
        (offset, parsed.assetAmount) = Bytes.readUInt128(_data, offset);
        // gas fee account index
        (offset, parsed.gasFeeAccountIndex) = Bytes.readUInt32(_data, offset);
        // gas fee asset id
        (offset, parsed.gasFeeAssetId) = Bytes.readUInt16(_data, offset);
        // gas fee asset amount
        (offset, parsed.gasFeeAssetAmount) = Bytes.readUInt16(_data, offset);

        offset += 8;

        require(offset == PACKED_WITHDRAW_PUBDATA_BYTES, "N");
        return parsed;
    }

    // Withdraw Nft pubdata
    struct WithdrawNft {
        uint8 txType;
        uint32 fromAccountIndex;
        uint32 creatorAccountIndex;
        uint16 creatorTreasuryRate;
        uint40 nftIndex;
        address nftL1Address;
        address toAddress;
        uint32 gasFeeAccountIndex;
        uint16 gasFeeAssetId;
        uint16 gasFeeAssetAmount;
        bytes32 nftContentHash;
        uint256 nftL1TokenId;
        bytes32 creatorAccountNameHash;
        uint32 collectionId;
    }

    uint256 internal constant PACKED_WITHDRAWNFT_PUBDATA_BYTES = 6 * CHUNK_SIZE;

    /// Deserialize withdraw pubdata
    function readWithdrawNftPubData(bytes memory _data) internal pure returns (WithdrawNft memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;
        // account index
        (offset, parsed.fromAccountIndex) = Bytes.readUInt32(_data, offset);
        // account name hash
        (offset, parsed.creatorAccountNameHash) = Bytes.readBytes32(_data, offset);
        // nft index
        (offset, parsed.nftIndex) = Bytes.readUInt40(_data, offset);
        // collection id
        (offset, parsed.collectionId) = Bytes.readUInt16(_data, offset);
        // empty data
        offset += 14;
        // nft l1 address
        (offset, parsed.nftL1Address) = Bytes.readAddress(_data, offset);
        // empty data
        offset += 12;
        // nft l1 address
        (offset, parsed.toAddress) = Bytes.readAddress(_data, offset);
        // gas fee account index
        (offset, parsed.gasFeeAccountIndex) = Bytes.readUInt32(_data, offset);
        // gas fee asset id
        (offset, parsed.gasFeeAssetId) = Bytes.readUInt16(_data, offset);
        // gas fee asset amount
        (offset, parsed.gasFeeAssetAmount) = Bytes.readUInt16(_data, offset);
        // empty data
        offset += 4;
        // nft content hash
        (offset, parsed.nftContentHash) = Bytes.readBytes32(_data, offset);
        // nft token id
        (offset, parsed.nftL1TokenId) = Bytes.readUInt256(_data, offset);
        // account name hash
        (offset, parsed.creatorAccountNameHash) = Bytes.readBytes32(_data, offset);

        require(offset == PACKED_WITHDRAWNFT_PUBDATA_BYTES, "N");
        return parsed;
    }

    // full exit pubdata
    struct FullExit {
        uint8 txType;
        uint32 accountIndex;
        uint16 assetId;
        uint128 assetAmount;
        bytes32 accountNameHash;
    }

    uint256 internal constant PACKED_FULLEXIT_PUBDATA_BYTES = 2 * CHUNK_SIZE;

    /// Serialize full exit pubdata
    function writeFullExitPubDataForPriorityQueue(FullExit memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
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
        // empty data
        offset += 9;
        // account name
        (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);

        require(offset == PACKED_FULLEXIT_PUBDATA_BYTES, "N");
        return parsed;
    }

    /// @notice Write full exit pubdata for priority queue check.
    function checkFullExitInPriorityQueue(FullExit memory _tx, bytes20 hashedPubData) internal pure returns (bool) {
        return Utils.hashBytesToBytes20(writeFullExitPubDataForPriorityQueue(_tx)) == hashedPubData;
    }

    // full exit nft pubdata
    struct FullExitNft {
        uint8 txType;
        uint32 accountIndex;
        uint32 creatorAccountIndex;
        uint16 creatorTreasuryRate;
        uint40 nftIndex;
        uint16 collectionId;
        address nftL1Address;
        bytes32 accountNameHash;
        bytes32 creatorAccountNameHash;
        bytes32 nftContentHash;
        uint256 nftL1TokenId;
    }

    uint256 internal constant PACKED_FULLEXITNFT_PUBDATA_BYTES = 6 * CHUNK_SIZE;

    /// Serialize full exit nft pubdata
    function writeFullExitNftPubDataForPriorityQueue(FullExitNft memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
            uint32(0),
            uint32(0),
            uint16(0),
            _tx.nftIndex,
            uint16(0), // collection id
            address(0x0), // nft l1 address
            _tx.accountNameHash, // account name hash
            bytes32(0), // creator account name hash
            bytes32(0), // nft content hash
            uint256(0) // token id
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
        // empty data
        offset += 16;
        // nft l1 address
        (offset, parsed.nftL1Address) = Bytes.readAddress(_data, offset);
        // empty data
        offset += 12;
        // account name hash
        (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);
        // creator account name hash
        (offset, parsed.creatorAccountNameHash) = Bytes.readBytes32(_data, offset);
        // nft index
        (offset, parsed.nftIndex) = Bytes.readUInt40(_data, offset);
        // nft content hash
        (offset, parsed.nftContentHash) = Bytes.readBytes32(_data, offset);
        // nft l1 token id
        (offset, parsed.nftL1TokenId) = Bytes.readUInt256(_data, offset);

        require(offset == PACKED_FULLEXITNFT_PUBDATA_BYTES, "N");
        return parsed;
    }

    /// @notice Write full exit nft pubdata for priority queue check.
    function checkFullExitNftInPriorityQueue(FullExitNft memory _tx, bytes20 hashedPubData) internal pure returns (bool) {
        return Utils.hashBytesToBytes20(writeFullExitNftPubDataForPriorityQueue(_tx)) == hashedPubData;
    }
}
