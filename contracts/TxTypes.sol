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


    struct UpdatePairRate {
        uint8 txType;
        uint16 pairIndex;
        uint16 feeRate;
        uint32 treasuryAccountIndex;
        uint16 treasuryRate;
    }

    uint256 internal constant PACKED_UPDATEPAIR_PUBDATA_BYTES = TX_TYPE_BYTES + TOKEN_PAIR_ID_BYTES + ACCOUNT_INDEX_BYTES + RATE_BYTES * 2;

    function writeUpdatePairRatePubdataForPriorityQueue(UpdatePairRate memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
            _tx.pairIndex,
            _tx.feeRate,
            _tx.treasuryAccountIndex,
            _tx.treasuryRate
        );
    }

    /// Deserialize update pair pubdata
    function readUpdatePairRatePubdata(bytes memory _data) internal pure returns (UpdatePairRate memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;

        (offset, parsed.pairIndex) = Bytes.readUInt16(_data, offset);
        (offset, parsed.feeRate) = Bytes.readUInt16(_data, offset);
        (offset, parsed.treasuryAccountIndex) = Bytes.readUInt32(_data, offset);
        (offset, parsed.treasuryRate) = Bytes.readUInt16(_data, offset);

        require(offset == PACKED_UPDATEPAIR_PUBDATA_BYTES, "N");
        return parsed;
    }

    /// @notice Write update pair pubdata for priority queue check.
    function checkUpdatePairRateInPriorityQueue(UpdatePairRate memory _tx, bytes20 hashedPubdata) internal pure returns (bool) {
        return Utils.hashBytesToBytes20(writeUpdatePairRatePubdataForPriorityQueue(_tx)) == hashedPubdata;
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

    uint256 internal constant PACKED_CREATEPAIR_PUBDATA_BYTES = TX_TYPE_BYTES + TOKEN_PAIR_ID_BYTES + ASSET_ID_BYTES * 2 + ACCOUNT_INDEX_BYTES + RATE_BYTES * 2;

    function writeCreatePairPubdataForPriorityQueue(CreatePair memory _tx) internal pure returns (bytes memory buf) {
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
    function readCreatePairPubdata(bytes memory _data) internal pure returns (CreatePair memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;

        (offset, parsed.pairIndex) = Bytes.readUInt16(_data, offset);
        (offset, parsed.assetAId) = Bytes.readUInt16(_data, offset);
        (offset, parsed.assetBId) = Bytes.readUInt16(_data, offset);
        (offset, parsed.feeRate) = Bytes.readUInt16(_data, offset);
        (offset, parsed.treasuryAccountIndex) = Bytes.readUInt32(_data, offset);
        (offset, parsed.treasuryRate) = Bytes.readUInt16(_data, offset);

        require(offset == PACKED_CREATEPAIR_PUBDATA_BYTES, "N");
        return parsed;
    }

    /// @notice Write create pair pubdata for priority queue check.
    function checkCreatePairInPriorityQueue(CreatePair memory _tx, bytes20 hashedPubdata) internal pure returns (bool) {
        return Utils.hashBytesToBytes20(writeCreatePairPubdataForPriorityQueue(_tx)) == hashedPubdata;
    }

    struct RegisterZNS {
        uint8 txType;
        bytes32 accountName;
        bytes32 accountNameHash;
        bytes32 pubKey;
    }

    uint256 internal constant PACKED_REGISTERZNS_PUBDATA_BYTES = TX_TYPE_BYTES + ACCOUNT_NAME_BYTES + ACCOUNT_NAME_HASH_BYTES + PUBKEY_BYTES;

    /// Serialize register zns pubdata
    function writeRegisterZNSPubdataForPriorityQueue(RegisterZNS memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
            _tx.accountName,
            _tx.accountNameHash, // account name hash
            _tx.pubKey
        );
    }

    /// Deserialize register zns pubdata
    function readRegisterZNSPubdata(bytes memory _data) internal pure returns (RegisterZNS memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;
        // account name
        (offset, parsed.accountName) = Bytes.readBytes32(_data, offset);
        (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);
        (offset, parsed.pubKey) = Bytes.readBytes32(_data, offset);

        require(offset == PACKED_REGISTERZNS_PUBDATA_BYTES, "N");
        return parsed;
    }

    /// @notice Write register zns pubdata for priority queue check.
    function checkRegisterZNSInPriorityQueue(RegisterZNS memory _tx, bytes20 hashedPubdata) internal pure returns (bool) {
        return Utils.hashBytesToBytes20(writeRegisterZNSPubdataForPriorityQueue(_tx)) == hashedPubdata;
    }

    // Deposit pubdata
    struct Deposit {
        uint8 txType;
        uint32 accountIndex;
        bytes32 accountNameHash;
        uint16 assetId;
        uint128 amount;
    }

    uint256 internal constant PACKED_DEPOSIT_PUBDATA_BYTES =
    TX_TYPE_BYTES + ACCOUNT_INDEX_BYTES + ACCOUNT_NAME_HASH_BYTES + ASSET_ID_BYTES + STATE_AMOUNT_BYTES;

    /// Serialize deposit pubdata
    function writeDepositPubdataForPriorityQueue(Deposit memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
            uint32(0),
            _tx.accountNameHash, // account name hash
            _tx.assetId, // asset id
            _tx.amount // state amount
        );
    }

    /// Deserialize deposit pubdata
    function readDepositPubdata(bytes memory _data) internal pure returns (Deposit memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;
        // account index
        (offset, parsed.accountIndex) = Bytes.readUInt32(_data, offset);
        // account name
        (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);
        // asset id
        (offset, parsed.assetId) = Bytes.readUInt16(_data, offset);
        // state amount
        (offset, parsed.amount) = Bytes.readUInt128(_data, offset);

        require(offset == PACKED_DEPOSIT_PUBDATA_BYTES, "N");
        return parsed;
    }

    /// @notice Write deposit pubdata for priority queue check.
    function checkDepositInPriorityQueue(Deposit memory _tx, bytes20 hashedPubdata) internal pure returns (bool) {
        return Utils.hashBytesToBytes20(writeDepositPubdataForPriorityQueue(_tx)) == hashedPubdata;
    }

    // TODO
    struct DepositNft {
        uint8 txType;
        uint32 accountIndex;
        bytes32 accountNameHash;
        address tokenAddress;
        uint256 nftTokenId;
        uint16 creatorTreasuryRate;
    }

    uint256 internal constant PACKED_DEPOSIT_NFT_PUBDATA_BYTES =
    TX_TYPE_BYTES + ACCOUNT_INDEX_BYTES + ACCOUNT_NAME_HASH_BYTES + ADDRESS_BYTES + NFT_TOKEN_ID_BYTES + CREATOR_TREASURY_RATE_BYTES;

    /// Serialize deposit pubdata
    function writeDepositNftPubdataForPriorityQueue(DepositNft memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
            _tx.accountNameHash, // account name hash
            _tx.tokenAddress, // token address
            _tx.nftTokenId, // nft token id
            _tx.creatorTreasuryRate
        );
    }

    /// Deserialize deposit pubdata
    function readDepositNftPubdata(bytes memory _data) internal pure returns (DepositNft memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;
        // account name
        (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);
        // asset id
        (offset, parsed.tokenAddress) = Bytes.readAddress(_data, offset);
        (offset, parsed.nftTokenId) = Bytes.readUInt256(_data, offset);
        (offset, parsed.creatorTreasuryRate) = Bytes.readUInt16(_data, offset);

        require(offset == PACKED_DEPOSIT_NFT_PUBDATA_BYTES, "N");
        return parsed;
    }

    /// @notice Write deposit pubdata for priority queue check.
    function checkDepositNftInPriorityQueue(DepositNft memory _tx, bytes20 hashedPubdata) internal pure returns (bool) {
        return Utils.hashBytesToBytes20(writeDepositNftPubdataForPriorityQueue(_tx)) == hashedPubdata;
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

    uint256 internal constant PACKED_WITHDRAW_PUBDATA_BYTES =
    TX_TYPE_BYTES + ACCOUNT_INDEX_BYTES + ADDRESS_BYTES + ASSET_ID_BYTES +
    STATE_AMOUNT_BYTES + ACCOUNT_INDEX_BYTES + ASSET_ID_BYTES + PACKED_FEE_AMOUNT_BYTES;

    /// Deserialize withdraw pubdata
    function readWithdrawPubdata(bytes memory _data) internal pure returns (Withdraw memory parsed) {
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
        // gas fee account index
        (offset, parsed.gasFeeAccountIndex) = Bytes.readUInt32(_data, offset);
        // gas fee asset id
        (offset, parsed.gasFeeAssetId) = Bytes.readUInt16(_data, offset);
        // gas fee asset amount
        (offset, parsed.gasFeeAssetAmount) = Bytes.readUInt16(_data, offset);

        require(offset == PACKED_WITHDRAW_PUBDATA_BYTES, "N");
        return parsed;
    }

    // Withdraw Nft pubdata
    struct WithdrawNft {
        uint8 txType;
        uint32 accountIndex;
        bytes32 accountNameHash;
        uint8 nftType;
        uint40 nftIndex;
        bytes32 nftContentHash;
        address nftL1Address;
        uint256 nftL1TokenId;
        uint32 amount;
        address toAddress;
        address proxyAddress;
        uint32 gasFeeAccountIndex;
        uint16 gasFeeAssetId;
        uint16 gasFeeAssetAmount;
    }

    uint256 internal constant PACKED_WITHDRAWNFT_PUBDATA_BYTES =
    TX_TYPE_BYTES + ACCOUNT_INDEX_BYTES + ACCOUNT_NAME_HASH_BYTES +
    NFT_TYPE_BYTES + NFT_INDEX_BYTES + NFT_CONTENT_HASH_BYTES + ADDRESS_BYTES + NFT_TOKEN_ID_BYTES + NFT_AMOUNT_BYTES
    + ADDRESS_BYTES + ADDRESS_BYTES + ACCOUNT_INDEX_BYTES + ASSET_ID_BYTES + PACKED_FEE_AMOUNT_BYTES;

    /// Deserialize withdraw pubdata
    function readWithdrawNftPubdata(bytes memory _data) internal pure returns (WithdrawNft memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;
        // account index
        (offset, parsed.accountIndex) = Bytes.readUInt32(_data, offset);
        // account name hash
        (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);
        // nft type
        (offset, parsed.nftType) = Bytes.readUInt8(_data, offset);
        // nft index
        (offset, parsed.nftIndex) = Bytes.readUInt40(_data, offset);
        // nft content hash
        (offset, parsed.nftContentHash) = Bytes.readBytes32(_data, offset);
        // nft l1 address
        (offset, parsed.nftL1Address) = Bytes.readAddress(_data, offset);
        // nft token id
        (offset, parsed.nftL1TokenId) = Bytes.readUInt256(_data, offset);
        // nft amount
        (offset, parsed.amount) = Bytes.readUInt32(_data, offset);
        // gas fee account index
        (offset, parsed.gasFeeAccountIndex) = Bytes.readUInt32(_data, offset);
        // gas fee asset id
        (offset, parsed.gasFeeAssetId) = Bytes.readUInt16(_data, offset);
        // gas fee asset amount
        (offset, parsed.gasFeeAssetAmount) = Bytes.readUInt16(_data, offset);

        require(offset == PACKED_WITHDRAWNFT_PUBDATA_BYTES, "N");
        return parsed;
    }

    // full exit pubdata
    struct FullExit {
        uint8 txType;
        uint32 accountIndex;
        bytes32 accountNameHash;
        uint16 assetId;
        uint128 assetAmount;
    }

    uint256 internal constant PACKED_FULLEXIT_PUBDATA_BYTES =
    TX_TYPE_BYTES + ACCOUNT_INDEX_BYTES + ACCOUNT_NAME_HASH_BYTES + ASSET_ID_BYTES + STATE_AMOUNT_BYTES;

    /// Serialize full exit pubdata
    function writeFullExitPubdataForPriorityQueue(FullExit memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
            uint32(0),
            _tx.accountNameHash, // account name
            _tx.assetId, // asset id
            uint128(0) // asset amount
        );
    }

    /// Deserialize full exit pubdata
    function readFullExitPubdata(bytes memory _data) internal pure returns (FullExit memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;
        // account index
        (offset, parsed.accountIndex) = Bytes.readUInt32(_data, offset);
        // account name
        (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);
        // asset id
        (offset, parsed.assetId) = Bytes.readUInt16(_data, offset);
        // asset state amount
        (offset, parsed.assetAmount) = Bytes.readUInt128(_data, offset);

        require(offset == PACKED_FULLEXIT_PUBDATA_BYTES, "N");
        return parsed;
    }

    /// @notice Write full exit pubdata for priority queue check.
    function checkFullExitInPriorityQueue(FullExit memory _tx, bytes20 hashedPubdata) internal pure returns (bool) {
        return Utils.hashBytesToBytes20(writeFullExitPubdataForPriorityQueue(_tx)) == hashedPubdata;
    }

    // full exit nft pubdata
    struct FullExitNft {
        uint8 txType;
        uint32 accountIndex;
        bytes32 accountNameHash;
        uint40 nftIndex;
        bytes32 nftContentHash;
        address nftL1Address;
        uint256 nftL1TokenId;
        address toAddress;
    }

    uint256 internal constant PACKED_FULLEXITNFT_PUBDATA_BYTES =
    TX_TYPE_BYTES + ACCOUNT_INDEX_BYTES + ACCOUNT_NAME_HASH_BYTES + NFT_INDEX_BYTES + NFT_CONTENT_HASH_BYTES
    + ADDRESS_BYTES + NFT_TOKEN_ID_BYTES + ADDRESS_BYTES;

    /// Serialize full exit nft pubdata
    function writeFullExitNftPubdataForPriorityQueue(FullExitNft memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
            uint32(0),
            _tx.accountNameHash, // account name
            _tx.nftIndex,
            bytes32(0),
            address(0x0), // nft l1 address
            uint256(0), // token id
            _tx.toAddress // receiver address
        );
    }

    /// Deserialize full exit nft pubdata
    function readFullExitNftPubdata(bytes memory _data) internal pure returns (FullExitNft memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;
        // account index
        (offset, parsed.accountIndex) = Bytes.readUInt32(_data, offset);
        // account name
        (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);
        // nft index
        (offset, parsed.nftIndex) = Bytes.readUInt40(_data, offset);
        // nft content hash
        (offset, parsed.nftContentHash) = Bytes.readBytes32(_data, offset);
        // nft l1 address
        (offset, parsed.nftL1Address) = Bytes.readAddress(_data, offset);
        // nft l1 token id
        (offset, parsed.nftL1TokenId) = Bytes.readUInt256(_data, offset);
        // to address
        (offset, parsed.toAddress) = Bytes.readAddress(_data, offset);

        require(offset == PACKED_FULLEXITNFT_PUBDATA_BYTES, "N");
        return parsed;
    }

    /// @notice Write full exit nft pubdata for priority queue check.
    function checkFullExitNftInPriorityQueue(FullExitNft memory _tx, bytes20 hashedPubdata) internal pure returns (bool) {
        return Utils.hashBytesToBytes20(writeFullExitNftPubdataForPriorityQueue(_tx)) == hashedPubdata;
    }
}
