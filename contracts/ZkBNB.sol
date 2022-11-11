// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./lib/SafeMathUInt128.sol";
import "./lib/SafeMathUInt32.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";
import "./interfaces/Events.sol";
import "./lib/Utils.sol";
import "./lib/Bytes.sol";
import "./lib/TxTypes.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/NFTFactory.sol";
import "./Config.sol";
import "./ZNSController.sol";
import "./Storage.sol";
import "./lib/NFTHelper.sol";

/// @title ZkBNB main contract
/// @author ZkBNB Team
contract ZkBNB is Events, Storage, Config, ReentrancyGuardUpgradeable, IERC721Receiver, NFTHelper {
    using SafeMath for uint256;
    using SafeMathUInt128 for uint128;
    using SafeMathUInt32 for uint32;

    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1052.md
    bytes32 private constant EMPTY_STRING_KECCAK = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    struct CommitBlockInfo {
        bytes32 newStateRoot;
        bytes publicData;
        uint256 timestamp;
        uint32[] publicDataOffsets;
        uint32 blockNumber;
        uint16 blockSize;
    }

    struct VerifyAndExecuteBlockInfo {
        StoredBlockInfo blockHeader;
        bytes[] pendingOnchainOpsPubData;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4){
        return this.onERC721Received.selector;
    }
    
    /// @notice Checks if Desert mode must be entered. If true - enters exodus mode and emits ExodusMode event.
    /// @dev Desert mode must be entered in case of current ethereum block number is higher than the oldest
    /// @dev of existed priority requests expiration block number.
    /// @return bool flag that is true if the Exodus mode must be entered.
    function activateDesertMode() public returns (bool) {
        // #if EASY_DESERT
        bool trigger = true;
        // #else
        trigger = block.number >= priorityRequests[firstPriorityRequestId].expirationBlock &&
        priorityRequests[firstPriorityRequestId].expirationBlock != 0;
        // #endif
        if (trigger) {
            if (!desertMode) {
                desertMode = true;
                emit DesertMode();
            }
            return true;
        } else {
            return false;
        }
    }

    /// @notice ZkBNB contract initialization. Can be external because Proxy contract intercepts illegal calls of this function.
    /// @param initializationParameters Encoded representation of initialization parameters:
    /// @dev _governanceAddress The address of Governance contract
    /// @dev _verifierAddress The address of Verifier contract
    /// @dev _genesisStateHash Genesis blocks (first block) state tree root hash
    function initialize(bytes calldata initializationParameters) external initializer {
        __ReentrancyGuard_init();

        (
        address _governanceAddress,
        address _verifierAddress,
        address _additionalZkBNB,
        address _znsController,
        address _znsResolver,
        bytes32 _genesisStateRoot
        ) = abi.decode(initializationParameters, (address, address, address, address, address, bytes32));

        verifier = ZkBNBVerifier(_verifierAddress);
        governance = Governance(_governanceAddress);
        additionalZkBNB = AdditionalZkBNB(_additionalZkBNB);
        znsController = ZNSController(_znsController);
        znsResolver = PublicResolver(_znsResolver);

        StoredBlockInfo memory zeroStoredBlockInfo = StoredBlockInfo(
            0,
            0,
            0,
            EMPTY_STRING_KECCAK,
            0,
            _genesisStateRoot,
            bytes32(0)
        );
        stateRoot = _genesisStateRoot;
        storedBlockHashes[0] = hashStoredBlockInfo(zeroStoredBlockInfo);
    }

    function registerZNS(string calldata _name, address _owner, bytes32 _zkbnbPubKeyX, bytes32 _zkbnbPubKeyY) external payable nonReentrant {
        // Register ZNS
        (bytes32 node,uint32 accountIndex) = znsController.registerZNS{value : msg.value}(_name, _owner, _zkbnbPubKeyX, _zkbnbPubKeyY, address(znsResolver));

        // Priority Queue request
        TxTypes.RegisterZNS memory _tx = TxTypes.RegisterZNS({
            txType : uint8(TxTypes.TxType.RegisterZNS),
            accountIndex : accountIndex,
            accountName : Utils.stringToBytes20(_name),
            accountNameHash : node,
            pubKeyX : _zkbnbPubKeyX,
            pubKeyY : _zkbnbPubKeyY
        });
        // compact pub data
        bytes memory pubData = TxTypes.writeRegisterZNSPubDataForPriorityQueue(_tx);

        // add into priority request queue
        addPriorityRequest(TxTypes.TxType.RegisterZNS, pubData);

        emit RegisterZNS(_name, node, _owner, _zkbnbPubKeyX, _zkbnbPubKeyY, accountIndex);
    }

    function isRegisteredZNSName(string memory _name) external view returns (bool) {
        return znsController.isRegisteredZNSName(_name);
    }

    function getZNSNamePrice(string calldata name) external view returns (uint256) {
        return znsController.getZNSNamePrice(name);
    }

    function getAddressByAccountNameHash(bytes32 accountNameHash) public view returns (address){
        return znsController.getOwner(accountNameHash);
    }

    /// @notice Deposit Native Assets to Layer 2 - transfer ether from user into contract, validate it, register deposit
    /// @param _accountName the receiver account name
    function depositBNB(string calldata _accountName) external payable {
        require(msg.value != 0, "ia");
        // TODO: `requireActive` should be modifier
        requireActive();
        bytes32 accountNameHash = znsController.getSubnodeNameHash(_accountName);
        require(znsController.isRegisteredNameHash(accountNameHash), "nr");
        registerDeposit(0, SafeCast.toUint128(msg.value), accountNameHash);
    }

    /// @notice Deposit or Lock BEP20 token to Layer 2 - transfer ERC20 tokens from user into contract, validate it, register deposit
    /// @param _token Token address
    /// @param _amount Token amount
    /// @param _accountName Receiver Layer 2 account name
    function depositBEP20(
        IERC20 _token,
        uint104 _amount,
        string calldata _accountName
    ) external {
        require(_amount != 0, "I");
        requireActive();
        bytes32 accountNameHash = znsController.getSubnodeNameHash(_accountName);
        require(znsController.isRegisteredNameHash(accountNameHash), "N");
        // Get asset id by its address
        uint16 assetId = governance.validateAssetAddress(address(_token));
        require(!governance.pausedAssets(assetId), "b");
        // token deposits are paused

        uint256 balanceBefore = _token.balanceOf(address(this));
        require(Utils.transferFromERC20(_token, msg.sender, address(this), SafeCast.toUint128(_amount)), "c");
        // token transfer failed deposit
        uint256 balanceAfter = _token.balanceOf(address(this));
        uint128 depositAmount = SafeCast.toUint128(balanceAfter.sub(balanceBefore));
        require(depositAmount <= MAX_DEPOSIT_AMOUNT, "C");
        require(depositAmount > 0, "D");

        registerDeposit(assetId, depositAmount, accountNameHash);
    }

    /// @notice Deposit NFT to Layer 2, ERC721 is supported
    function depositNft(
        string calldata _accountName,
        address _nftL1Address,
        uint256 _nftL1TokenId
    ) external {
        requireActive();
        bytes32 accountNameHash = znsController.getSubnodeNameHash(_accountName);
        require(znsController.isRegisteredNameHash(accountNameHash), "nr");
        // Transfer the tokens to this contract
        bool success;
        try IERC721(_nftL1Address).safeTransferFrom(
            msg.sender,
            address(this),
            _nftL1TokenId
        ){
            success = true;
        }catch{
            success = false;
        }
        require(success, "ntf");
        // check owner
        require(IERC721(_nftL1Address).ownerOf(_nftL1TokenId) == address(this), "i");

        // check if the nft is mint from layer-2
        bytes32 nftKey = keccak256(abi.encode(_nftL1Address, _nftL1TokenId));
        require(l2Nfts[nftKey].nftContentHash != bytes32(0), "l1 nft is not allowed");

        bytes32 nftContentHash = l2Nfts[nftKey].nftContentHash;
        uint16 collectionId = l2Nfts[nftKey].collectionId;
        uint40 nftIndex = l2Nfts[nftKey].nftIndex;
        uint32 creatorAccountIndex = l2Nfts[nftKey].creatorAccountIndex;
        uint16 creatorTreasuryRate = l2Nfts[nftKey].creatorTreasuryRate;

        TxTypes.DepositNft memory _tx = TxTypes.DepositNft({
            txType : uint8(TxTypes.TxType.DepositNft),
            accountIndex : 0, // unknown at this point
            nftIndex : nftIndex,
            creatorAccountIndex : creatorAccountIndex,
            creatorTreasuryRate : creatorTreasuryRate,
            nftContentHash : nftContentHash,
            accountNameHash : accountNameHash,
            collectionId : collectionId
        });

        // compact pub data
        bytes memory pubData = TxTypes.writeDepositNftPubDataForPriorityQueue(_tx);

        // add into priority request queue
        addPriorityRequest(TxTypes.TxType.DepositNft, pubData);

        // delete nft from account at L1
        _removeAccountNft(msg.sender, _nftL1Address, nftIndex);

        emit DepositNft(accountNameHash, nftContentHash, _nftL1Address, _nftL1TokenId, collectionId);
    }

    function withdrawOrStoreNFT(TxTypes.WithdrawNft memory op) internal {
        require(op.nftIndex <= MAX_NFT_INDEX, "invalid nft index");

        // get nft factory
        address _factoryAddress = address(getNFTFactory(op.creatorAccountNameHash, op.collectionId));
        bytes32 nftKey = keccak256(abi.encode(_factoryAddress, op.nftIndex));
        bool alreadyMintedFlag = false;
        if (l2Nfts[nftKey].nftContentHash != bytes32(0)) {
            alreadyMintedFlag = true;
        }
        // get layer-1 address by account name hash
        bytes memory _emptyExtraData;
        if (alreadyMintedFlag) {
            /// This is a NFT from layer 1, withdraw id directly
            try IERC721(_factoryAddress).safeTransferFrom{gas : WITHDRAWAL_NFT_GAS_LIMIT}(
                address(this),
                op.toAddress,
                op.nftIndex
            ) {
                // add nft to account at L1
                _addAccountNft(op.toAddress, _factoryAddress, op.nftIndex);

                emit WithdrawNft(op.fromAccountIndex, _factoryAddress, op.toAddress, op.nftIndex);
            }catch{
                storePendingNFT(op);
            }
        } else {
            address _creatorAddress = getAddressByAccountNameHash(op.creatorAccountNameHash);
            // get nft factory
            address _factoryAddress = address(getNFTFactory(op.creatorAccountNameHash, op.collectionId));
            // store into l2 nfts
            bytes32 nftKey = keccak256(abi.encode(_factoryAddress, op.nftIndex));
            l2Nfts[nftKey] = L2NftInfo({
            nftIndex : op.nftIndex,
            creatorAccountIndex : op.creatorAccountIndex,
            creatorTreasuryRate : op.creatorTreasuryRate,
            nftContentHash : op.nftContentHash,
            collectionId : uint16(op.collectionId)
            });
            try NFTFactory(_factoryAddress).mintFromZkBNB(
                _creatorAddress,
                op.toAddress,
                op.nftIndex,
                op.nftContentHash,
                _emptyExtraData
            ) {
                // add nft to account at L1
                _addAccountNft(op.toAddress, _factoryAddress, op.nftIndex);

                emit WithdrawNft(op.fromAccountIndex, _factoryAddress, op.toAddress, op.nftIndex);
            } catch {
                storePendingNFT(op);
            }
        }
    }

    /// @notice Get a registered NFTFactory according to the creator accountNameHash and the collectionId
    /// @param _creatorAccountNameHash creator account name hash of the factory
    /// @param _collectionId collection id of the nft collection related to this creator
    function getNFTFactory(bytes32 _creatorAccountNameHash, uint32 _collectionId) public view returns (address) {
        address _factoryAddr = nftFactories[_creatorAccountNameHash][_collectionId];
        if (_factoryAddr == address(0)) {
            require(address(defaultNFTFactory) != address(0), "F");
            // NFTFactory does not set
            return defaultNFTFactory;
        } else {
            return _factoryAddr;
        }
    }

    /// @dev Save NFT as pending to withdraw
    function storePendingNFT(TxTypes.WithdrawNft memory op) internal {
        pendingWithdrawnNFTs[op.nftIndex] = op;
        emit WithdrawalNFTPending(op.nftIndex);
    }

    /// @notice  Withdraws NFT from zkSync contract to the owner
    /// @param _nftIndex Id of NFT token
    function withdrawPendingNFTBalance(uint40 _nftIndex) external {
        TxTypes.WithdrawNft memory op = pendingWithdrawnNFTs[_nftIndex];
        withdrawOrStoreNFT(op);
        delete pendingWithdrawnNFTs[_nftIndex];
    }

    /// @notice Get pending balance that the user can withdraw
    /// @param _address The layer-1 address
    /// @param _assetAddr Token address
    function getPendingBalance(address _address, address _assetAddr) public view returns (uint128) {
        uint16 assetId = 0;
        if (_assetAddr != address(0)) {
            assetId = governance.validateAssetAddress(_assetAddr);
        }
        return pendingBalances[packAddressAndAssetId(_address, assetId)].balanceToWithdraw;
    }

    /// @notice  Withdraws tokens from ZkBNB contract to the owner
    /// @param _owner Address of the tokens owner
    /// @param _token Address of tokens, zero address is used for Native Asset
    /// @param _amount Amount to withdraw to request.
    ///         NOTE: We will call ERC20.transfer(.., _amount), but if according to internal logic of ERC20 token ZkBNB contract
    ///         balance will be decreased by value more then _amount we will try to subtract this value from user pending balance
    function withdrawPendingBalance(
        address payable _owner,
        address _token,
        uint128 _amount
    ) external {
        uint16 _assetId = 0;
        if (_token != address(0)) {
            _assetId = governance.validateAssetAddress(_token);
        }
        bytes22 packedBalanceKey = packAddressAndAssetId(_owner, _assetId);
        uint128 balance = pendingBalances[packedBalanceKey].balanceToWithdraw;
        uint128 amount = Utils.minU128(balance, _amount);
        if (_assetId == 0) {
            (bool success,) = _owner.call{value : _amount}("");
            // Native Asset withdraw failed
            require(success, "d");
        } else {
            // We will allow withdrawals of `value` such that:
            // `value` <= user pending balance
            // `value` can be bigger then `_amount` requested if token takes fee from sender in addition to `_amount` requested
            amount = this.transferERC20(IERC20(_token), _owner, amount, balance);
        }
        pendingBalances[packedBalanceKey].balanceToWithdraw = balance - _amount;
        emit Withdrawal(_assetId, _amount);
    }

    /// @notice Sends tokens
    /// @dev NOTE: will revert if transfer call fails or rollup balance difference (before and after transfer) is bigger than _maxAmount
    /// @dev This function is used to allow tokens to spend zkSync contract balance up to amount that is requested
    /// @param _token Token address
    /// @param _to Address of recipient
    /// @param _amount Amount of tokens to transfer
    /// @param _maxAmount Maximum possible amount of tokens to transfer to this account
    function transferERC20(
        IERC20 _token,
        address _to,
        uint128 _amount,
        uint128 _maxAmount
    ) external returns (uint128 withdrawnAmount) {
        require(msg.sender == address(this), "5");
        // can be called only from this contract as one "external" call (to revert all this function state changes if it is needed)

        uint256 balanceBefore = _token.balanceOf(address(this));
        _token.transfer(_to, _amount);
        uint256 balanceAfter = _token.balanceOf(address(this));
        uint256 balanceDiff = balanceBefore.sub(balanceAfter);
        //        require(balanceDiff > 0, "C");
        // transfer is considered successful only if the balance of the contract decreased after transfer
        require(balanceDiff <= _maxAmount, "7");
        // rollup balance difference (before and after transfer) is bigger than `_maxAmount`

        // It is safe to convert `balanceDiff` to `uint128` without additional checks, because `balanceDiff <= _maxAmount`
        return uint128(balanceDiff);
    }

    /// @notice Commit block
    /// @notice 1. Checks onchain operations, timestamp.
    function commitBlocks(
        StoredBlockInfo memory _lastCommittedBlockData,
        CommitBlockInfo[] memory _newBlocksData
    )
    external
    {
        delegateAdditional();
    }

    /// @notice Verify block index and proofs
    function verifyAndExecuteOneBlock(VerifyAndExecuteBlockInfo memory _block, uint32 _verifiedBlockIdx) internal {
        // Ensure block was committed
        require(
            hashStoredBlockInfo(_block.blockHeader) ==
            storedBlockHashes[_block.blockHeader.blockNumber],
            "A" // executing block should be committed
        );
        // blocks must in order
        require(_block.blockHeader.blockNumber == totalBlocksVerified + _verifiedBlockIdx + 1, "k");

        bytes32 pendingOnchainOpsHash = EMPTY_STRING_KECCAK;
        for (uint32 i = 0; i < _block.pendingOnchainOpsPubData.length; ++i) {
            bytes memory pubData = _block.pendingOnchainOpsPubData[i];

            TxTypes.TxType txType = TxTypes.TxType(uint8(pubData[0]));

            if (txType == TxTypes.TxType.Withdraw) {
                TxTypes.Withdraw memory _tx = TxTypes.readWithdrawPubData(pubData);
                // Circuit guarantees that partial exits are available only for fungible tokens
                //                require(_tx.assetId <= MAX_FUNGIBLE_ASSET_ID, "A");
                withdrawOrStore(uint16(_tx.assetId), _tx.toAddress, _tx.assetAmount);
            } else if (txType == TxTypes.TxType.FullExit) {
                TxTypes.FullExit memory _tx = TxTypes.readFullExitPubData(pubData);
                //                require(_tx.assetId <= MAX_FUNGIBLE_ASSET_ID, "B");
                // get layer-1 address by account name hash
                address creatorAddress = getAddressByAccountNameHash(_tx.accountNameHash);
                withdrawOrStore(uint16(_tx.assetId), creatorAddress, _tx.assetAmount);
            } else if (txType == TxTypes.TxType.FullExitNft) {
                TxTypes.FullExitNft memory _tx = TxTypes.readFullExitNftPubData(pubData);
                // get address by account name hash
                address toAddr = getAddressByAccountNameHash(_tx.accountNameHash);
                // withdraw nft
                if (_tx.nftContentHash != bytes32(0)) {
                    TxTypes.WithdrawNft memory _withdrawNftTx = TxTypes.WithdrawNft({
                    txType : uint8(TxTypes.TxType.WithdrawNft),
                    fromAccountIndex : _tx.accountIndex,
                    creatorAccountIndex : _tx.creatorAccountIndex,
                    creatorTreasuryRate : _tx.creatorTreasuryRate,
                    nftIndex : _tx.nftIndex,
                    toAddress : toAddr,
                    gasFeeAccountIndex : 0,
                    gasFeeAssetId : 0,
                    gasFeeAssetAmount : 0,
                    nftContentHash : _tx.nftContentHash,
                    creatorAccountNameHash : _tx.accountNameHash,
                    collectionId : _tx.collectionId
                    });
                    withdrawOrStoreNFT(_withdrawNftTx);
                }
            } else if (txType == TxTypes.TxType.WithdrawNft) {
                TxTypes.WithdrawNft memory _tx = TxTypes.readWithdrawNftPubData(pubData);
                // withdraw NFT
                withdrawOrStoreNFT(_tx);
            } else {
                // unsupported _tx in block verification
                revert("l");
            }

            pendingOnchainOpsHash = Utils.concatHash(pendingOnchainOpsHash, pubData);
        }
        // incorrect onchain txs executed
        require(pendingOnchainOpsHash == _block.blockHeader.pendingOnchainOperationsHash, "m");
    }

    /// @dev 1. Try to send token to _recipients
    /// @dev 2. On failure: Increment _recipients balance to withdraw.
    function withdrawOrStore(
        uint16 _assetId,
        address _recipient,
        uint128 _amount
    ) internal {
        bytes22 packedBalanceKey = packAddressAndAssetId(_recipient, _assetId);

        bool sent = false;
        if (_assetId == 0) {
            address payable toPayable = address(uint160(_recipient));
            sent = sendBNBNoRevert(toPayable, _amount);
        } else {
            address tokenAddr = governance.assetAddresses(_assetId);
            // We use `_transferERC20` here to check that `ERC20` token indeed transferred `_amount`
            // and fail if token subtracted from ZkBNB balance more then `_amount` that was requested.
            // This can happen if token subtracts fee from sender while transferring `_amount` that was requested to transfer.
            try this.transferERC20{gas : WITHDRAWAL_GAS_LIMIT}(IERC20(tokenAddr), _recipient, _amount, _amount) {
                sent = true;
            } catch {
                sent = false;
            }
        }
        if (sent) {
            emit Withdrawal(_assetId, _amount);
        } else {
            increaseBalanceToWithdraw(packedBalanceKey, _amount);
        }
    }

    /// @notice Verify layer-2 blocks proofs
    /// @param _blocks Verified blocks info
    /// @param _proofs proofs
    function verifyAndExecuteBlocks(VerifyAndExecuteBlockInfo[] memory _blocks, uint256[] memory _proofs) external {
        requireActive();
        governance.requireActiveValidator(msg.sender);

        uint64 priorityRequestsExecuted = 0;
        uint32 nBlocks = uint32(_blocks.length);
        // proof public inputs
        for (uint16 i = 0; i < _blocks.length; ++i) {
            priorityRequestsExecuted += _blocks[i].blockHeader.priorityOperations;
            // update account root
            verifyAndExecuteOneBlock(_blocks[i], i);
            emit BlockVerification(_blocks[i].blockHeader.blockNumber);
        }
        uint numBlocksVerified = 0;
        bool[] memory blockVerified = new bool[](nBlocks);
        uint[] memory batch = new uint[](nBlocks);
        uint firstBlockSize = 0;
        while (numBlocksVerified < nBlocks) {
            // Find all blocks of the same type
            uint batchLength = 0;
            for (uint i = 0; i < nBlocks; i++) {
                if (blockVerified[i] == false) {
                    if (batchLength == 0) {
                        firstBlockSize = _blocks[i].blockHeader.blockSize;
                        batch[batchLength++] = i;
                    } else {
                        if (_blocks[i].blockHeader.blockSize == firstBlockSize) {
                            batch[batchLength++] = i;
                        }
                    }
                }
            }
            // Prepare the data for batch verification
            uint[] memory publicInputs = new uint[](batchLength);
            uint[] memory proofs = new uint[](batchLength * 8);
            uint16 block_size = 0;
            uint256 q = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
            for (uint i = 0; i < batchLength; i++) {
                uint blockIdx = batch[i];
                blockVerified[blockIdx] = true;
                // verify block proof
                VerifyAndExecuteBlockInfo memory _block = _blocks[blockIdx];
                publicInputs[i] = uint256(_block.blockHeader.commitment) % q;
                for (uint j = 0; j < 8; j++) {
                    proofs[8 * i + j] = _proofs[8 * blockIdx + j];
                }
                block_size = _block.blockHeader.blockSize;
            }
            bool res = verifier.verifyBatchProofs(proofs, publicInputs, batchLength, block_size);
            require(res, "inp");
            numBlocksVerified += batchLength;
        }

        // update account root
        stateRoot = _blocks[nBlocks - 1].blockHeader.stateRoot;
        firstPriorityRequestId += priorityRequestsExecuted;
        totalCommittedPriorityRequests -= priorityRequestsExecuted;
        totalOpenPriorityRequests -= priorityRequestsExecuted;

        totalBlocksVerified += nBlocks;
        // Can't execute blocks more then committed.
        require(totalBlocksVerified <= totalBlocksCommitted, "n");
    }

    /// @notice Register deposit request - pack pubdata, add into onchainOpsCheck and emit OnchainDeposit event
    /// @param _assetId Asset by id
    /// @param _amount Asset amount
    /// @param _accountNameHash Receiver Account Name
    function registerDeposit(
        uint16 _assetId,
        uint128 _amount,
        bytes32 _accountNameHash
    ) internal {
        // Priority Queue request
        TxTypes.Deposit memory _tx = TxTypes.Deposit({
            txType : uint8(TxTypes.TxType.Deposit),
            accountIndex : 0, // unknown at the moment
            accountNameHash : _accountNameHash,
            assetId : _assetId,
            amount : _amount
        });
        // compact pub data
        bytes memory pubData = TxTypes.writeDepositPubDataForPriorityQueue(_tx);
        // add into priority request queue
        addPriorityRequest(TxTypes.TxType.Deposit, pubData);
        emit Deposit(_assetId, _accountNameHash, _amount);
    }

    /// @notice Saves priority request in storage
    /// @dev Calculates expiration block for request, store this request and emit NewPriorityRequest event
    /// @param _txType Rollup _tx type
    /// @param _pubData _tx pub data
    function addPriorityRequest(TxTypes.TxType _txType, bytes memory _pubData) internal {
        // Expiration block is: current block number + priority expiration delta
        uint64 expirationBlock = uint64(block.number + PRIORITY_EXPIRATION);

        uint64 nextPriorityRequestId = firstPriorityRequestId + totalOpenPriorityRequests;

        bytes20 hashedPubData = Utils.hashBytesToBytes20(_pubData);

        priorityRequests[nextPriorityRequestId] = PriorityTx({
            hashedPubData : hashedPubData,
            expirationBlock : expirationBlock,
            txType : _txType
        });

        emit NewPriorityRequest(msg.sender, nextPriorityRequestId, _txType, _pubData, uint256(expirationBlock));

        totalOpenPriorityRequests++;
    }

    /// @notice Register full exit request - pack pubdata, add priority request
    /// @param _accountName account name
    /// @param _asset Token address, 0 address for BNB
    function requestFullExit(string calldata _accountName, address _asset) public {
        delegateAdditional();
    }

    /// @notice Register full exit nft request - pack pubdata, add priority request
    /// @param _accountName account name
    /// @param _nftIndex account NFT index in zkbnb network
    function requestFullExitNft(string calldata _accountName, uint32 _nftIndex) public {
        delegateAdditional();
    }

    function setDefaultNFTFactory(NFTFactory _factory) external {
        delegateAdditional();
    }

    /// @notice Sends ETH
    /// @param _to Address of recipient
    /// @param _amount Amount of tokens to transfer
    /// @return bool flag indicating that transfer is successful
    function sendBNBNoRevert(address payable _to, uint256 _amount) internal returns (bool) {
        (bool callSuccess,) = _to.call{gas : WITHDRAWAL_GAS_LIMIT, value : _amount}("");
        return callSuccess;
    }

    function increaseBalanceToWithdraw(bytes22 _packedBalanceKey, uint128 _amount) internal {
        uint128 balance = pendingBalances[_packedBalanceKey].balanceToWithdraw;
        pendingBalances[_packedBalanceKey] = PendingBalance(balance.add(_amount), FILLED_GAS_RESERVE_VALUE);
    }

    /// @notice Reverts unverified blocks
    function revertBlocks(StoredBlockInfo[] memory _blocksToRevert) external {
        delegateAdditional();
    }

    /// @notice Delegates the call to the additional part of the main contract.
    /// @notice Should be only use to delegate the external calls as it passes the calldata
    /// @notice All functions delegated to additional contract should NOT be nonReentrant
    function delegateAdditional() internal {
        address _target = address(additionalZkBNB);
        assembly {
        // The pointer to the free memory slot
            let ptr := mload(0x40)
        // Copy function signature and arguments from calldata at zero position into memory at pointer position
            calldatacopy(ptr, 0x0, calldatasize())
        // Delegatecall method of the implementation contract, returns 0 on error
            let result := delegatecall(gas(), _target, ptr, calldatasize(), 0x0, 0)
        // Get the size of the last return data
            let size := returndatasize()
        // Copy the size length of bytes from return data at zero position to pointer position
            returndatacopy(ptr, 0x0, size)

        // Depending on result value
            switch result
            case 0 {
            // End execution and revert state changes
                revert(ptr, size)
            }
            default {
            // Return data with length of size at pointers position
                return (ptr, size)
            }
        }
    }
}
