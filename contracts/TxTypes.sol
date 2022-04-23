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
        Deposit,
        DepositERC721,
        DepositNFT,
        GenericTransfer,
        Swap,
        AddLiquidity,
        RemoveLiquidity,
        Withdraw,
        MintNft,
        SetNftPrice,
        BuyNft,
        WithdrawNFT,
        FullExit,
        FullExitNFT
    }

    /// NftType is an enum of possible NFT types
    enum NftType {
        ERC1155,
        ERC721
    }

    // Byte lengths
    // operation type bytes
    uint8 internal constant TX_TYPE_BYTES = 1;
    // nft type
    uint8 internal constant NFT_TYPE_BYTES = 1;
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
    uint8 internal constant NFT_ASSET_ID_BYTES = 4;
    // nft token id bytes
    uint8 internal constant NFT_TOKEN_ID_BYTES = 32;
    // nft index bytes
    uint8 internal constant NFT_INDEX_BYTES = 32;
    // nft content hash bytes
    uint8 internal constant NFT_CONTENT_HASH_BYTES = 32;
    // pair index
    uint8 internal constant PAIR_INDEX_BYTES = 2;

    struct RegisterZNS {
        uint8 txType;
        bytes32 accountName;
        bytes32 pubKey;
    }

    uint256 internal constant PACKED_REGISTERZNS_PUBDATA_BYTES = TX_TYPE_BYTES + ACCOUNT_NAME_BYTES + PUBKEY_BYTES;

    /// Serialize register zns pubdata
    function writeRegisterZNSPubdataForPriorityQueue(RegisterZNS memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
            _tx.accountName, // account name
            _tx.pubKey
        );
    }

    /// Deserialize register zns pubdata
    function readRegisterZNSPubdata(bytes memory _data) internal pure returns (RegisterZNS memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;
        // account name
        (offset, parsed.accountName) = Bytes.readBytes32(_data, offset);
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
            _tx.accountIndex,
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

    struct DepositNFT {
        uint8 txType;
        bytes32 accountNameHash;
        address tokenAddress;
        uint8 nftType;
        uint256 nftTokenId;
        uint32 amount;
    }

    uint256 internal constant PACKED_DEPOSIT_NFT_PUBDATA_BYTES =
    TX_TYPE_BYTES + ACCOUNT_NAME_HASH_BYTES + ADDRESS_BYTES + NFT_TYPE_BYTES + NFT_TOKEN_ID_BYTES + NFT_AMOUNT_BYTES;

    /// Serialize deposit pubdata
    function writeDepositNFTPubdataForPriorityQueue(DepositNFT memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
            _tx.accountNameHash, // account name hash
            _tx.tokenAddress, // token address
            _tx.nftType, // nft type
            _tx.nftTokenId,
            _tx.amount
        );
    }

    /// Deserialize deposit pubdata
    function readDepositNFTPubdata(bytes memory _data) internal pure returns (DepositNFT memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;
        // account name
        (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);
        // asset id
        (offset, parsed.tokenAddress) = Bytes.readAddress(_data, offset);
        // state amount
        (offset, parsed.nftType) = Bytes.readUInt8(_data, offset);
        // state amount
        (offset, parsed.nftTokenId) = Bytes.readUInt256(_data, offset);
        // state amount
        (offset, parsed.amount) = Bytes.readUInt32(_data, offset);

        require(offset == PACKED_DEPOSIT_NFT_PUBDATA_BYTES, "N");
        return parsed;
    }

    // TODO
    struct DepositERC721 {
        uint8 txType;
        bytes32 accountNameHash;
        address tokenAddress;
        uint256 nftTokenId;
    }

    uint256 internal constant PACKED_DEPOSIT_ERC721_PUBDATA_BYTES =
    TX_TYPE_BYTES + ACCOUNT_NAME_HASH_BYTES + ADDRESS_BYTES + NFT_TOKEN_ID_BYTES;

    /// Serialize deposit pubdata
    function writeDepositERC721PubdataForPriorityQueue(DepositERC721 memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
            _tx.accountNameHash, // account name hash
            _tx.tokenAddress, // token address
            _tx.nftTokenId // nft token id
        );
    }

    /// Deserialize deposit pubdata
    function readDepositERC721Pubdata(bytes memory _data) internal pure returns (DepositERC721 memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;
        // account name
        (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);
        // asset id
        (offset, parsed.tokenAddress) = Bytes.readAddress(_data, offset);
        // state amount
        (offset, parsed.nftTokenId) = Bytes.readUInt256(_data, offset);

        require(offset == PACKED_DEPOSIT_ERC721_PUBDATA_BYTES, "N");
        return parsed;
    }

    /// @notice Write deposit pubdata for priority queue check.
    function checkDepositERC721InPriorityQueue(DepositERC721 memory _tx, bytes20 hashedPubdata) internal pure returns (bool) {
        return Utils.hashBytesToBytes20(writeDepositERC721PubdataForPriorityQueue(_tx)) == hashedPubdata;
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
    struct WithdrawNFT {
        uint8 txType;
        uint32 accountIndex;
        bytes32 accountNameHash;
        address tokenAddress;
        address toAddress;
        address proxyAddress;
        uint8 nftType;
        uint256 nftTokenId;
        uint32 amount;
        bytes32 nftContentHash;
        uint32 nftAssetId;
        uint32 gasFeeAccountIndex;
        uint16 gasFeeAssetId;
        uint16 gasFeeAssetAmount;
    }

    uint256 internal constant PACKED_WITHDRAWNFT_PUBDATA_BYTES =
    TX_TYPE_BYTES + ACCOUNT_INDEX_BYTES + ACCOUNT_NAME_HASH_BYTES + ADDRESS_BYTES + ADDRESS_BYTES + ADDRESS_BYTES +
    NFT_TYPE_BYTES + NFT_TOKEN_ID_BYTES + NFT_AMOUNT_BYTES + NFT_CONTENT_HASH_BYTES +
    NFT_ASSET_ID_BYTES + ACCOUNT_INDEX_BYTES + ASSET_ID_BYTES + PACKED_FEE_AMOUNT_BYTES;

    /// Deserialize withdraw pubdata
    function readWithdrawNFTPubdata(bytes memory _data) internal pure returns (WithdrawNFT memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;
        // account index
        (offset, parsed.accountIndex) = Bytes.readUInt32(_data, offset);
        // account name hash
        (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);
        // token address
        (offset, parsed.tokenAddress) = Bytes.readAddress(_data, offset);
        // to address
        (offset, parsed.toAddress) = Bytes.readAddress(_data, offset);
        // proxy address
        (offset, parsed.proxyAddress) = Bytes.readAddress(_data, offset);
        // amount
        (offset, parsed.amount) = Bytes.readUInt32(_data, offset);
        // nft content hash
        (offset, parsed.nftContentHash) = Bytes.readBytes32(_data, offset);
        // nft token type
        (offset, parsed.nftType) = Bytes.readUInt8(_data, offset);
        // nft token id
        (offset, parsed.nftTokenId) = Bytes.readUInt256(_data, offset);
        // nft asset id
        (offset, parsed.nftAssetId) = Bytes.readUInt32(_data, offset);
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
            _tx.accountIndex,
            _tx.accountNameHash, // account name
            _tx.assetId, // asset id
            _tx.assetAmount // asset amount
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
    struct FullExitNFT {
        uint8 txType;
        uint32 accountIndex;
        bytes32 accountNameHash;
        address tokenAddress;
        address toAddress;
        address proxyAddress;
        uint8 nftType;
        uint256 nftTokenId;
        uint32 amount;
        bytes32 nftContentHash;
        uint32 nftAssetId;
    }

    uint256 internal constant PACKED_FULLEXITNFT_PUBDATA_BYTES =
    TX_TYPE_BYTES + ACCOUNT_INDEX_BYTES + ACCOUNT_NAME_HASH_BYTES + ADDRESS_BYTES + ADDRESS_BYTES + ADDRESS_BYTES +
    NFT_TYPE_BYTES + NFT_TOKEN_ID_BYTES + NFT_AMOUNT_BYTES + NFT_CONTENT_HASH_BYTES + NFT_ASSET_ID_BYTES;

    /// Serialize full exit nft pubdata
    function writeFullExitNFTPubdataForPriorityQueue(FullExitNFT memory _tx) internal pure returns (bytes memory buf) {
        buf = abi.encodePacked(
            _tx.txType,
            _tx.accountIndex,
            _tx.accountNameHash, // account name
            _tx.tokenAddress, // nft l1 address
            _tx.toAddress, // receiver address
            _tx.proxyAddress, // proxy address
            _tx.nftTokenId, // token id
            _tx.amount,
            _tx.nftContentHash,
            _tx.nftAssetId
        );
    }

    /// Deserialize full exit nft pubdata
    function readFullExitNFTPubdata(bytes memory _data) internal pure returns (FullExitNFT memory parsed) {
        // NOTE: there is no check that variable sizes are same as constants (i.e. TOKEN_BYTES), fix if possible.
        uint256 offset = TX_TYPE_BYTES;
        // account index
        (offset, parsed.accountIndex) = Bytes.readUInt32(_data, offset);
        // account name
        (offset, parsed.accountNameHash) = Bytes.readBytes32(_data, offset);
        // nft address
        (offset, parsed.tokenAddress) = Bytes.readAddress(_data, offset);
        // nft address
        (offset, parsed.toAddress) = Bytes.readAddress(_data, offset);
        // nft address
        (offset, parsed.proxyAddress) = Bytes.readAddress(_data, offset);
        // nft token id
        (offset, parsed.nftTokenId) = Bytes.readUInt256(_data, offset);
        // nft amount
        (offset, parsed.amount) = Bytes.readUInt32(_data, offset);
        // nft content hash
        (offset, parsed.nftContentHash) = Bytes.readBytes32(_data, offset);
        // nft asset id
        (offset, parsed.nftAssetId) = Bytes.readUInt32(_data, offset);

        require(offset == PACKED_FULLEXITNFT_PUBDATA_BYTES, "N");
        return parsed;
    }

    /// @notice Write full exit nft pubdata for priority queue check.
    function checkFullExitNFTInPriorityQueue(FullExitNFT memory _tx, bytes20 hashedPubdata) internal pure returns (bool) {
        return Utils.hashBytesToBytes20(writeFullExitNFTPubdataForPriorityQueue(_tx)) == hashedPubdata;
    }
}
