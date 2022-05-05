// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

pragma experimental ABIEncoderV2;

import "./ReentrancyGuard.sol";
import "./SafeMath.sol";
import "./SafeMathUInt128.sol";
import "./SafeMathUInt32.sol";
import "./SafeCast.sol";
import "./Storage.sol";
import "./Events.sol";
import "./Utils.sol";
import "./Bytes.sol";
import "./TxTypes.sol";
import "./UpgradeableMaster.sol";
import "./IERC1155.sol";
import "./IERC721.sol";
import "./NFTFactory.sol";
import "./Config.sol";
import "./ZNSController.sol";

/// @title Zecrey main contract
/// @author Zecrey Team
contract ZecreyLegend is UpgradeableMaster, Events, Storage, Config, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeMathUInt128 for uint128;
    using SafeMathUInt32 for uint32;

    // TODO
    bytes32 private constant EMPTY_STRING_KECCAK = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    struct CommitBlockInfo {
        bytes32 newAccountRoot;
        bytes publicData;
        uint256 timestamp;
        uint32[] publicDataOffsets;
        uint32 blockNumber;
    }

    struct VerifyBlockInfo {
        BlockHeader blockHeader;
        bytes[] pendingOnchainOpsPubdata;
    }

    // Upgrade functional
    /// @notice Notice period before activation preparation status of upgrade mode
    function getNoticePeriod() external pure override returns (uint256) {
        return UPGRADE_NOTICE_PERIOD;
    }

    /// @notice Notification that upgrade notice period started
    /// @dev Can be external because Proxy contract intercepts illegal calls of this function
    function upgradeNoticePeriodStarted() external override {
        upgradeStartTimestamp = block.timestamp;
    }

    /// @notice Notification that upgrade preparation status is activated
    /// @dev Can be external because Proxy contract intercepts illegal calls of this function
    function upgradePreparationStarted() external override {
        upgradePreparationActive = true;
        upgradePreparationActivationTime = block.timestamp;
        require(block.timestamp >= upgradeStartTimestamp.add(approvedUpgradeNoticePeriod));
    }

    /// @dev When upgrade is finished or canceled we must clean upgrade-related state.
    function clearUpgradeStatus() internal {
        upgradePreparationActive = false;
        upgradePreparationActivationTime = 0;
        approvedUpgradeNoticePeriod = UPGRADE_NOTICE_PERIOD;
        emit NoticePeriodChange(approvedUpgradeNoticePeriod);
        upgradeStartTimestamp = 0;
        for (uint256 i = 0; i < SECURITY_COUNCIL_MEMBERS_NUMBER; ++i) {
            securityCouncilApproves[i] = false;
        }
        numberOfApprovalsFromSecurityCouncil = 0;
    }

    /// @notice Notification that upgrade canceled
    /// @dev Can be external because Proxy contract intercepts illegal calls of this function
    function upgradeCanceled() external override {
        clearUpgradeStatus();
    }

    /// @notice Notification that upgrade finishes
    /// @dev Can be external because Proxy contract intercepts illegal calls of this function
    function upgradeFinishes() external override {
        clearUpgradeStatus();
    }

    /// @notice Checks that contract is ready for upgrade
    /// @return bool flag indicating that contract is ready for upgrade
    function isReadyForUpgrade() external view override returns (bool) {
        return !desertMode;
    }

    function upgrade(bytes calldata upgradeParameters) external nonReentrant {}

    function cutUpgradeNoticePeriod() external {
        /// All functions delegated to additional contract should NOT be nonReentrant
        delegateAdditional();
    }

    /// @notice Checks if Desert mode must be entered. If true - enters exodus mode and emits ExodusMode event.
    /// @dev Desert mode must be entered in case of current ethereum block number is higher than the oldest
    /// @dev of existed priority requests expiration block number.
    /// @return bool flag that is true if the Exodus mode must be entered.
    function activateDesertMode() public returns (bool) {
        // #if EASY_EXODUS
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

    /// @notice Zecrey contract initialization. Can be external because Proxy contract intercepts illegal calls of this function.
    /// @param initializationParameters Encoded representation of initialization parameters:
    /// @dev _governanceAddress The address of Governance contract
    /// @dev _verifierAddress The address of Verifier contract
    /// @dev _genesisStateHash Genesis blocks (first block) state tree root hash
    function initialize(bytes calldata initializationParameters) external {
        initializeReentrancyGuard();

        (
        address _governanceAddress,
        address _verifierAddress,
        address _additionalZecreylegend,
        address _znsController,
        address _znsResolver,
        bytes32 _genesisAccountRoot
        ) = abi.decode(initializationParameters, (address, address, address, address, address, bytes32));

        verifier = ZecreyVerifier(_verifierAddress);
        governance = Governance(_governanceAddress);
        additionalZecreyLegend = AdditionalZecreyLegend(_additionalZecreylegend);
        znsController = ZNSController(_znsController);
        znsResolver = PublicResolver(_znsResolver);

        BlockHeader memory zeroBlockHeader = BlockHeader(
            0,
            0,
            EMPTY_STRING_KECCAK,
            0,
            _genesisAccountRoot,
            bytes32(0)
        );
        storedBlockHeaderHashes[0] = hashBlockHeader(zeroBlockHeader);
        approvedUpgradeNoticePeriod = UPGRADE_NOTICE_PERIOD;
        emit NoticePeriodChange(approvedUpgradeNoticePeriod);
    }

    /// @notice Sends tokens
    /// @dev NOTE: will revert if transfer call fails or rollup balance difference (before and after transfer) is bigger than _maxAmount
    /// @dev This function is used to allow tokens to spend Zecrey contract balance up to amount that is requested
    /// @param _token Token address
    /// @param _to Address of recipient
    /// @param _amount Amount of tokens to transfer
    /// @param _maxAmount Maximum possible amount of tokens to transfer to this account
    function _transferERC20(
        IERC20 _token,
        address _to,
        uint128 _amount,
        uint128 _maxAmount
    ) external returns (uint128 withdrawnAmount) {
        require(msg.sender == address(this), "5");
        // wtg10 - can be called only from this contract as one "external" call (to revert all this function state changes if it is needed)

        uint256 balanceBefore = _token.balanceOf(address(this));
        require(Utils.sendERC20(_token, _to, _amount), "6");
        // wtg11 - ERC20 transfer fails
        uint256 balanceAfter = _token.balanceOf(address(this));
        uint256 balanceDiff = balanceBefore.sub(balanceAfter);
        require(balanceDiff <= _maxAmount, "7");
        // wtg12 - rollup balance difference (before and after transfer) is bigger than _maxAmount

        return SafeCast.toUint128(balanceDiff);
    }

    function registerZNS(string calldata _name, address _owner, bytes32 _zecreyPubKey) external nonReentrant {
        bytes32 node = znsController.registerZNS(_name, _owner, _zecreyPubKey, address(znsResolver));
        // Priority Queue request
        TxTypes.RegisterZNS memory _tx = TxTypes.RegisterZNS({
        txType : uint8(TxTypes.TxType.RegisterZNS),
        accountName : Utils.stringToBytes32(_name),
        accountNameHash : node,
        pubKey : _zecreyPubKey
        });
        // compact pub data
        bytes memory pubData = TxTypes.writeRegisterZNSPubdataForPriorityQueue(_tx);

        // add into priority request queue
        addPriorityRequest(TxTypes.TxType.RegisterZNS, pubData);

        emit RegisterZNS(_name, node, _owner, _zecreyPubKey);
    }

    /// @notice Deposit Native Assets to Layer 2 - transfer ether from user into contract, validate it, register deposit
    /// @param _accountNameHash The receiver Layer 2 account name
    function depositBNB(bytes32 _accountNameHash) external payable {
        require(msg.value != 0, "ia");
        requireActive();
        require(znsController.isRegisteredHash(_accountNameHash), "not registered");
        registerDeposit(0, SafeCast.toUint128(msg.value), _accountNameHash);
    }

    /// @notice Deposit or Lock ERC20 token to Layer 2 - transfer ERC20 tokens from user into contract, validate it, register deposit
    /// @param _token Token address
    /// @param _amount Token amount
    /// @param _accountNameHash Receiver Layer 2 account name hash
    function depositBEP20(
        IERC20 _token,
        uint104 _amount,
        bytes32 _accountNameHash
    ) external nonReentrant {
        require(_amount != 0, "ia");
        requireActive();
        require(znsController.isRegisteredHash(_accountNameHash), "not registered");
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

        registerDeposit(assetId, depositAmount, _accountNameHash);
    }

    /// @notice Deposit NFT to Layer 2, both ERC721 and ERC1155 is supported
    function depositNFT(
        bytes32 _accountNameHash,
        address _tokenAddress,
        TxTypes.NftType _nftType,
        uint256 _nftTokenId,
        uint32 _amount // can be zero
    ) external nonReentrant {
        requireActive();
        require(znsController.isRegisteredHash(_accountNameHash), "not registered");
        // Transfer the tokens to this contract
        bool success = Utils.transferFromNFT(msg.sender, address(this), _nftType, _tokenAddress, _nftTokenId, _amount);

        require(success, "nft transfer failure");

        // Priority Queue request
        TxTypes.DepositNFT memory _tx = TxTypes.DepositNFT({
        txType : uint8(TxTypes.TxType.DepositERC721),
        accountNameHash : _accountNameHash,
        accountIndex : 0, // unknown at this point
        tokenAddress : _tokenAddress,
        nftType : uint8(_nftType),
        nftTokenId : _nftTokenId,
        amount : _amount
        });
        // compact pub data
        bytes memory pubData = TxTypes.writeDepositNFTPubdataForPriorityQueue(_tx);

        // add into priority request queue
        addPriorityRequest(TxTypes.TxType.DepositNFT, pubData);

        emit DepositNFT(_accountNameHash, _tokenAddress, uint8(_nftType), _nftTokenId, _amount);
    }

    function withdrawNFT(
        bytes32 _creatorAccountNameHash,
        address _nftL1Address,
        address _toAddress,
        address _proxyAddress,
        TxTypes.NftType _nftType,
        uint256 _nftL1TokenId,
        uint32 _amount,
        bytes32 _nftContentHash
    ) internal {
        // get layer-1 address by account name hash
        address _creatorAddress = getAddressByAccountNameHash(_creatorAccountNameHash);
        bytes memory _emptyExtraData;
        bool success;
        if (_nftL1Address != address(0x00)) {
            /// This is a NFT from layer 1, withdraw id directly
            success = Utils.transferFromNFT(_creatorAddress, _toAddress, _nftType, _nftL1Address, _nftL1TokenId, _amount);
        } else {
            /// This is a NFT from layer 2
            // TODO minter _proxyAddress
            if (_proxyAddress != address(0x00)) {
                success = mintFromZecrey(_creatorAddress, _toAddress, _proxyAddress, _nftL1TokenId, _amount, _nftContentHash, _emptyExtraData);
            } else {
                // TODO mint nft from Zecrey nft factory
                if (_amount == 1) {// ERC721
                    // TODO 721 address
                    success = mintFromZecrey(_creatorAddress, _toAddress, _proxyAddress, _nftL1TokenId, _amount, _nftContentHash, _emptyExtraData);
                } else {// ERC1155
                    // TODO 1155 address
                    success = mintFromZecrey(_creatorAddress, _toAddress, _proxyAddress, _nftL1TokenId, _amount, _nftContentHash, _emptyExtraData);
                }
            }
        }

        require(success, "nft transfer failure");

        emit WithdrawNFT(_creatorAccountNameHash, _nftL1Address, _toAddress, _proxyAddress, uint8(_nftType), _nftL1TokenId, _amount);
    }

    function mintFromZecrey(
        address _creatorAddress,
        address _toAddress,
        address _factoryAddress,
        uint256 _nftTokenId,
        uint32 _amount,
        bytes32 _nftContentHash,
        bytes memory _extraData
    ) internal returns (bool success) {
        if (_amount == 0) return true;

        try NFTFactory(_factoryAddress).mintFromZecrey(
            _creatorAddress,
            _toAddress,
            _factoryAddress,
            _nftTokenId,
            _amount,
            _nftContentHash,
            _extraData
        ) {
            success = true;
        } catch {
            success = false;
        }
        return success;
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

    /// @notice  Withdraws tokens from Zecrey contract to the owner
    /// @param _owner Address of the tokens owner
    /// @param _token Address of tokens, zero address is used for Native Asset
    /// @param _amount Amount to withdraw to request.
    ///         NOTE: We will call ERC20.transfer(.., _amount), but if according to internal logic of ERC20 token Zecrey contract
    ///         balance will be decreased by value more then _amount we will try to subtract this value from user pending balance
    function withdrawPendingBalance(
        address payable _owner,
        address _token,
        uint128 _amount
    ) external nonReentrant {
        if (_token == address(0)) {
            registerWithdrawal(0, _amount, _owner);
            (bool success,) = _owner.call{value : _amount}("");
            // Native Asset withdraw failed
            require(success, "d");
        } else {
            uint16 assetId = governance.validateAssetAddress(_token);
            bytes22 packedBalanceKey = packAddressAndAssetId(_owner, assetId);
            uint128 balance = pendingBalances[packedBalanceKey].balanceToWithdraw;
            // We will allow withdrawals of `value` such that:
            // `value` <= user pending balance
            // `value` can be bigger then `_amount` requested if token takes fee from sender in addition to `_amount` requested
            uint128 withdrawnAmount = this._transferERC20(IERC20(_token), _owner, _amount, balance);
            registerWithdrawal(assetId, withdrawnAmount, _owner);
        }
    }

    /// @dev Process one block commit using previous block BlockHeader,
    /// @dev returns new block BlockHeader
    function commitOneBlock(BlockHeader memory _previousBlock, CommitBlockInfo memory _newBlock)
    internal
    view
    returns (BlockHeader memory storedNewBlock)
    {
        // only commit next block
        require(_newBlock.blockNumber == _previousBlock.blockNumber + 1, "f");

        // Check timestamp of the new block
        {
            // Block should be after previous block
            require(_newBlock.timestamp >= _previousBlock.timestamp, "g");
        }

        // Check onchain operations
        (
        bytes32 pendingOnchainOpsHash,
        uint64 priorityReqCommitted
        ) = collectOnchainOps(_newBlock);

        // Create block commitment for verification proof
        // TODO mock on BNB Chain, using MiMC
        bytes32 commitment = createBlockCommitment(_previousBlock, _newBlock);

        return
        BlockHeader(
            _newBlock.blockNumber,
            priorityReqCommitted,
            pendingOnchainOpsHash,
            _newBlock.timestamp,
            _newBlock.newAccountRoot,
            commitment
        );
    }

    /// @notice Commit block
    /// @notice 1. Checks onchain operations, timestamp.
    function commitBlocks(
        BlockHeader memory _lastCommittedBlockData,
        CommitBlockInfo[] memory _newBlocksData
    )
    external
    nonReentrant
    {
        requireActive();
        governance.requireActiveValidator(msg.sender);
        // Check that we commit blocks after last committed block
        // incorrect previous block data
        require(storedBlockHeaderHashes[totalBlocksCommitted] == hashBlockHeader(_lastCommittedBlockData), "i");

        for (uint32 i = 0; i < _newBlocksData.length; ++i) {
            _lastCommittedBlockData = commitOneBlock(_lastCommittedBlockData, _newBlocksData[i]);

            totalCommittedPriorityRequests += _lastCommittedBlockData.priorityOperations;
            storedBlockHeaderHashes[_lastCommittedBlockData.blockNumber] = hashBlockHeader(_lastCommittedBlockData);

            emit BlockCommit(_lastCommittedBlockData.blockNumber);
        }

        totalBlocksCommitted += uint32(_newBlocksData.length);

        require(totalCommittedPriorityRequests <= totalOpenPriorityRequests, "j");
    }

    function getAddressByAccountNameHash(bytes32 accountNameHash) public view returns (address){
        return znsController.getOwner(accountNameHash);
    }

    /// @notice Verify block index and proofs
    function verifyOneBlock(VerifyBlockInfo memory _block, uint32 _verifiedBlockIdx) internal {
        // Ensure block was committed
        require(
            hashBlockHeader(_block.blockHeader) ==
            storedBlockHeaderHashes[_block.blockHeader.blockNumber],
            "exe10" // executing block should be committed
        );
        // blocks must in order
        require(_block.blockHeader.blockNumber == totalBlocksVerified + _verifiedBlockIdx + 1, "k");

        bytes32 pendingOnchainOpsHash = EMPTY_STRING_KECCAK;
        for (uint32 i = 0; i < _block.pendingOnchainOpsPubdata.length; ++i) {
            bytes memory pubData = _block.pendingOnchainOpsPubdata[i];

            TxTypes.TxType txType = TxTypes.TxType(uint8(pubData[0]));

            if (txType == TxTypes.TxType.Withdraw) {
                TxTypes.Withdraw memory _tx = TxTypes.readWithdrawPubdata(pubData);
                // Circuit guarantees that partial exits are available only for fungible tokens
                require(_tx.assetId <= MAX_FUNGIBLE_ASSET_ID, "mf1");
                withdrawOrStore(uint16(_tx.assetId), _tx.toAddress, _tx.assetAmount);
            } else if (txType == TxTypes.TxType.FullExit) {
                TxTypes.FullExit memory _tx = TxTypes.readFullExitPubdata(pubData);
                require(_tx.assetId <= MAX_FUNGIBLE_ASSET_ID, "mf1");
                // get layer-1 address by account name hash
                address creatorAddress = getAddressByAccountNameHash(_tx.accountNameHash);
                withdrawOrStore(uint16(_tx.assetId), creatorAddress, _tx.assetAmount);
            } else if (txType == TxTypes.TxType.FullExitNFT) {
                // TODO need more operations
                // TODO check params for NFT address
                TxTypes.FullExitNFT memory _tx = TxTypes.readFullExitNFTPubdata(pubData);
                // withdraw nft
                if (_tx.amount != 0) {
                    withdrawNFT(_tx.accountNameHash, _tx.nftL1Address, _tx.toAddress, _tx.proxyAddress, TxTypes.NftType(_tx.nftType), _tx.nftL1TokenId, _tx.amount, _tx.nftContentHash);
                }
            } else if (txType == TxTypes.TxType.WithdrawNFT) {
                TxTypes.WithdrawNFT memory _tx = TxTypes.readWithdrawNFTPubdata(pubData);
                // withdraw NFT
                withdrawNFT(_tx.accountNameHash, _tx.nftL1Address, _tx.toAddress, _tx.proxyAddress, TxTypes.NftType(_tx.nftType), _tx.nftL1TokenId, _tx.amount, _tx.nftContentHash);
            } else {
                // unsupported _tx in block verification
                revert("l");
            }

            pendingOnchainOpsHash = Utils.concatHash(pendingOnchainOpsHash, pubData);
        }
        // incorrect onchain txs executed
        require(pendingOnchainOpsHash == _block.blockHeader.pendingOnchainOperationsHash, "m");
    }

    /// @notice Verify layer-2 blocks proofs
    /// @param _blocks Verified blocks info
    /// @param _proofs proofs
    function verifyBlocks(VerifyBlockInfo[] memory _blocks, uint256[] memory _proofs) external nonReentrant {
        requireActive();
        governance.requireActiveValidator(msg.sender);

        uint64 priorityRequestsExecuted = 0;
        uint32 nBlocks = uint32(_blocks.length);
        // proof public inputs
        uint256[] memory inputs = new uint256[](3 * _blocks.length);
        for (uint16 i = 0; i < _blocks.length; ++i) {
            verifyOneBlock(_blocks[i], i);
            priorityRequestsExecuted += _blocks[i].blockHeader.priorityOperations;
            // verify block proof
            inputs[3 * i] = uint256(accountRoot);
            inputs[3 * i + 1] = uint256(_blocks[i].blockHeader.accountRoot);
            inputs[3 * i + 2] = uint256(_blocks[i].blockHeader.commitment);
            // update account root
            accountRoot = _blocks[i].blockHeader.accountRoot;
            emit BlockVerification(_blocks[i].blockHeader.blockNumber);
        }
        bool res = verifier.verifyBatchProofs(_proofs, inputs, _blocks.length);
        require(res, "invalid proof");
        firstPriorityRequestId += priorityRequestsExecuted;
        totalCommittedPriorityRequests -= priorityRequestsExecuted;
        totalOpenPriorityRequests -= priorityRequestsExecuted;

        totalBlocksVerified += nBlocks;
        // Can't execute blocks more then committed.
        require(totalBlocksVerified <= totalBlocksCommitted, "n");
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
            // and fail if token subtracted from Zecrey balance more then `_amount` that was requested.
            // This can happen if token subtracts fee from sender while transferring `_amount` that was requested to transfer.
            try this._transferERC20{gas : WITHDRAWAL_GAS_LIMIT}(IERC20(tokenAddr), _recipient, _amount, _amount) {
                sent = true;
            } catch {
                sent = false;
            }
        }
        if (sent) {
            emit Withdrawal(_assetId, _amount);
        } else {
            increaseBalanceToWithdraw(packedBalanceKey, _amount);
            emit WithdrawalPending(_assetId, _amount);
        }
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
        bytes memory pubData = TxTypes.writeDepositPubdataForPriorityQueue(_tx);
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

    /// @notice Register withdrawal - update user balance and emit OnchainWithdrawal event
    /// @param _token - token by id
    /// @param _amount - token amount
    /// @param _to - address to withdraw to
    function registerWithdrawal(
        uint16 _token,
        uint128 _amount,
        address payable _to
    ) internal {
        bytes22 packedBalanceKey = packAddressAndAssetId(_to, _token);
        uint128 balance = pendingBalances[packedBalanceKey].balanceToWithdraw;
        pendingBalances[packedBalanceKey].balanceToWithdraw = balance.sub(_amount);
        emit Withdrawal(_token, _amount);
    }

    /// @notice Collect onchain ops and ensure it was not executed before
    function collectOnchainOps(CommitBlockInfo memory _newBlockData)
    internal
    view
    returns (
        bytes32 processableOperationsHash,
        uint64 priorityOperationsProcessed
    )
    {
        bytes memory pubData = _newBlockData.publicData;

        uint64 uncommittedPriorityRequestsOffset = firstPriorityRequestId + totalCommittedPriorityRequests;
        priorityOperationsProcessed = 0;
        processableOperationsHash = EMPTY_STRING_KECCAK;

        for (uint16 i = 0; i < _newBlockData.publicDataOffsets.length; ++i) {
            uint32 pubdataOffset = _newBlockData.publicDataOffsets[i];
            require(pubdataOffset < pubData.length, "A1");

            TxTypes.TxType txType = TxTypes.TxType(uint8(pubData[pubdataOffset]));
            if (txType == TxTypes.TxType.RegisterZNS) {
                bytes memory txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_REGISTERZNS_PUBDATA_BYTES);

                TxTypes.RegisterZNS memory registerZNSData = TxTypes.readRegisterZNSPubdata(txPubData);
                checkPriorityOperation(registerZNSData, uncommittedPriorityRequestsOffset + priorityOperationsProcessed);
                priorityOperationsProcessed++;
            } else if (txType == TxTypes.TxType.Deposit) {
                bytes memory txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_DEPOSIT_PUBDATA_BYTES);

                TxTypes.Deposit memory depositData = TxTypes.readDepositPubdata(txPubData);
                checkPriorityOperation(depositData, uncommittedPriorityRequestsOffset + priorityOperationsProcessed);
                priorityOperationsProcessed++;
            } else {

                bytes memory txPubData;

                if (txType == TxTypes.TxType.Withdraw) {
                    txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_WITHDRAW_PUBDATA_BYTES);
                } else if (txType == TxTypes.TxType.WithdrawNFT) {
                    txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_WITHDRAWNFT_PUBDATA_BYTES);
                } else if (txType == TxTypes.TxType.FullExit) {
                    txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_FULLEXIT_PUBDATA_BYTES);

                    TxTypes.FullExit memory fullExitData = TxTypes.readFullExitPubdata(txPubData);

                    checkPriorityOperation(
                        fullExitData,
                        uncommittedPriorityRequestsOffset + priorityOperationsProcessed
                    );
                    priorityOperationsProcessed++;
                } else if (txType == TxTypes.TxType.FullExitNFT) {
                    txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_FULLEXITNFT_PUBDATA_BYTES);

                    TxTypes.FullExitNFT memory fullExitNFTData = TxTypes.readFullExitNFTPubdata(txPubData);

                    checkPriorityOperation(
                        fullExitNFTData,
                        uncommittedPriorityRequestsOffset + priorityOperationsProcessed
                    );
                    priorityOperationsProcessed++;
                } else {
                    // unsupported _tx
                    revert("F");
                }
                processableOperationsHash = Utils.concatHash(processableOperationsHash, txPubData);
            }
        }
    }

    /// @notice Checks that register zns is same as _tx in priority queue
    /// @param _registerZNS register zns
    /// @param _priorityRequestId _tx's id in priority queue
    function checkPriorityOperation(TxTypes.RegisterZNS memory _registerZNS, uint64 _priorityRequestId) internal view {
        TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
        // incorrect priority _tx type
        require(priorReqType == TxTypes.TxType.RegisterZNS, "H");

        bytes20 hashedPubdata = priorityRequests[_priorityRequestId].hashedPubData;
        require(TxTypes.checkRegisterZNSInPriorityQueue(_registerZNS, hashedPubdata), "I");
    }

    /// @notice Checks that deposit is same as _tx in priority queue
    /// @param _deposit Deposit data
    /// @param _priorityRequestId _tx's id in priority queue
    function checkPriorityOperation(TxTypes.Deposit memory _deposit, uint64 _priorityRequestId) internal view {
        TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
        // incorrect priority _tx type
        require(priorReqType == TxTypes.TxType.Deposit, "H");

        bytes20 hashedPubdata = priorityRequests[_priorityRequestId].hashedPubData;
        require(TxTypes.checkDepositInPriorityQueue(_deposit, hashedPubdata), "I");
    }

    /// @notice Checks that FullExit is same as _tx in priority queue
    /// @param _fullExit FullExit data
    /// @param _priorityRequestId _tx's id in priority queue
    function checkPriorityOperation(TxTypes.FullExit memory _fullExit, uint64 _priorityRequestId) internal view {
        TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
        // incorrect priority _tx type
        require(priorReqType == TxTypes.TxType.FullExit, "J");

        bytes20 hashedPubdata = priorityRequests[_priorityRequestId].hashedPubData;
        require(TxTypes.checkFullExitInPriorityQueue(_fullExit, hashedPubdata), "K");
    }

    /// @notice Checks that FullExitNFT is same as _tx in priority queue
    /// @param _fullExitNFT FullExit nft data
    /// @param _priorityRequestId _tx's id in priority queue
    function checkPriorityOperation(TxTypes.FullExitNFT memory _fullExitNFT, uint64 _priorityRequestId) internal view {
        TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
        // incorrect priority _tx type
        require(priorReqType == TxTypes.TxType.FullExitNFT, "J");


        bytes20 hashedPubdata = priorityRequests[_priorityRequestId].hashedPubData;
        require(TxTypes.checkFullExitNFTInPriorityQueue(_fullExitNFT, hashedPubdata), "K");
    }

    /// @notice Register full exit request - pack pubdata, add priority request
    /// @param _accountNameHash account name hash
    /// @param _asset Token address, 0 address for BNB
    function requestFullExit(bytes32 _accountNameHash, address _asset) public nonReentrant {
        requireActive();
        require(znsController.isRegisteredHash(_accountNameHash), "not registered");
        // get address by account name hash
        address creatorAddress = getAddressByAccountNameHash(_accountNameHash);
        require(msg.sender == creatorAddress, "invalid address");


        uint16 assetId;
        if (_asset == address(0)) {
            assetId = 0;
        } else {
            assetId = governance.validateAssetAddress(_asset);
        }


        // Priority Queue request
        TxTypes.FullExit memory _tx = TxTypes.FullExit({
        txType : uint8(TxTypes.TxType.FullExit),
        accountIndex : 0, // unknown at this point
        accountNameHash : _accountNameHash,
        assetId : assetId,
        assetAmount : 0 // unknown at this point
        });
        bytes memory pubData = TxTypes.writeFullExitPubdataForPriorityQueue(_tx);
        addPriorityRequest(TxTypes.TxType.FullExit, pubData);

        // User must fill storage slot of balancesToWithdraw(msg.sender, tokenId) with nonzero value
        // In this case operator should just overwrite this slot during confirming withdrawal
        bytes22 packedBalanceKey = packAddressAndAssetId(msg.sender, assetId);
        pendingBalances[packedBalanceKey].gasReserveValue = FILLED_GAS_RESERVE_VALUE;
    }

    /// @notice Register full exit nft request - pack pubdata, add priority request
    /// @param _accountNameHash account name hash
    /// @param _nftIndex account NFT index in zecrey network
    // TODO
    function requestFullExitNFT(bytes32 _accountNameHash, uint32 _nftIndex) public nonReentrant {
        requireActive();
        require(znsController.isRegisteredHash(_accountNameHash), "not registered");
        require(_nftIndex < MAX_FUNGIBLE_ASSET_ID, "T");
        // get address by account name hash
        address creatorAddress = getAddressByAccountNameHash(_accountNameHash);
        require(msg.sender == creatorAddress, "invalid address");

        // Priority Queue request
        TxTypes.FullExitNFT memory _tx = TxTypes.FullExitNFT({
        txType : uint8(TxTypes.TxType.FullExitNFT),
        accountIndex : 0, // unknown
        accountNameHash : _accountNameHash,
        nftType : 0, // unknown
        nftIndex : _nftIndex,
        nftContentHash : bytes32(0x0), // unknown,
        nftL1Address : address(0x0), // unknown
        nftL1TokenId : 0, // unknown
        amount : 0, //unknown
        toAddress : creatorAddress,
        proxyAddress : address(0x0) // unknown
        });
        bytes memory pubData = TxTypes.writeFullExitNFTPubdataForPriorityQueue(_tx);
        addPriorityRequest(TxTypes.TxType.FullExitNFT, pubData);
    }


    /// @dev Creates block commitment from its data
    // TODO create commitment
    function createBlockCommitment(
        BlockHeader memory _previousBlock,
        CommitBlockInfo memory _newBlockData
    ) internal view returns (bytes32 commitment) {
        /*
        uint32 blockNumber;
        bytes32 onchainOpsRoot;
        bytes32 newAccountRoot;
        uint256 timestamp;
        bytes32 commitment;
        bytes onchainOpsPubData;
        uint16 onchainOpsCount;
        bytes32[ONCHAINOPS_DEPTH] onchainOpsMerkleProof;
        */
        commitment = keccak256(abi.encode(storedBlockHeaderHashes[_previousBlock.blockNumber],
            _newBlockData.blockNumber, _newBlockData.publicData));
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
    function revertBlocks(CommitBlockInfo[] memory _blocksToRevert) external {
        delegateAdditional();
    }

    /// @notice Delegates the call to the additional part of the main contract.
    /// @notice Should be only use to delegate the external calls as it passes the calldata
    /// @notice All functions delegated to additional contract should NOT be nonReentrant
    function delegateAdditional() internal {
        address _target = address(additionalZecreyLegend);
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
