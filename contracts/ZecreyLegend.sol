// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

pragma experimental ABIEncoderV2;

import "./ReentrancyGuard.sol";
import "./SafeMath.sol";
import "./SafeMathUInt128.sol";
import "./SafeMathUInt32.sol";
import "./SafeCast.sol";
import "./Utils.sol";

import "./Storage.sol";
import "./Events.sol";

import "./Bytes.sol";
import "./TxTypes.sol";

import "./UpgradeableMaster.sol";
import "./IERC1155.sol";
import "./IERC721.sol";
import "./IL2MintableNFT.sol";
import "./Config.sol";

/// @title Zecrey main contract
/// @author Zecrey Team
contract Zecrey is UpgradeableMaster, Events, Storage, Config, ReentrancyGuard {
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
        return 0;
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
        approvedUpgradeNoticePeriod = config.UPGRADE_NOTICE_PERIOD();
        emit NoticePeriodChange(approvedUpgradeNoticePeriod);
        upgradeStartTimestamp = 0;
        for (uint256 i = 0; i < config.SECURITY_COUNCIL_MEMBERS_NUMBER(); ++i) {
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
        // security council members
        // TODO to be confirmed
        address payable[3] memory SECURITY_COUNCIL_MEMBERS = [
        payable(address(0xE9b15a2D396B349ABF60e53ec66Bcf9af262D449)),
        payable(address(0xE9b15a2D396B349ABF60e53ec66Bcf9af262D449)),
        payable(address(0xE9b15a2D396B349ABF60e53ec66Bcf9af262D449))
        ];
        uint256 SECURITY_COUNCIL_2_WEEKS_THRESHOLD = 1;
        uint256 SECURITY_COUNCIL_1_WEEK_THRESHOLD = 2;
        uint256 SECURITY_COUNCIL_3_DAYS_THRESHOLD = 3;
        for (uint256 id = 0; id < config.SECURITY_COUNCIL_MEMBERS_NUMBER(); ++id) {
            if (SECURITY_COUNCIL_MEMBERS[id] == msg.sender) {
                require(upgradeStartTimestamp != 0);
                require(securityCouncilApproves[id] == false);
                securityCouncilApproves[id] = true;
                numberOfApprovalsFromSecurityCouncil++;

                if (numberOfApprovalsFromSecurityCouncil == SECURITY_COUNCIL_2_WEEKS_THRESHOLD) {
                    if (approvedUpgradeNoticePeriod > 2 weeks) {
                        approvedUpgradeNoticePeriod = 2 weeks;
                        emit NoticePeriodChange(approvedUpgradeNoticePeriod);
                    }
                } else if (numberOfApprovalsFromSecurityCouncil == SECURITY_COUNCIL_1_WEEK_THRESHOLD) {
                    if (approvedUpgradeNoticePeriod > 1 weeks) {
                        approvedUpgradeNoticePeriod = 1 weeks;
                        emit NoticePeriodChange(approvedUpgradeNoticePeriod);
                    }
                } else if (numberOfApprovalsFromSecurityCouncil == SECURITY_COUNCIL_3_DAYS_THRESHOLD) {
                    if (approvedUpgradeNoticePeriod > 3 days) {
                        approvedUpgradeNoticePeriod = 3 days;
                        emit NoticePeriodChange(approvedUpgradeNoticePeriod);
                    }
                }

                break;
            }
        }
    }

    /// @notice Checks if Desert mode must be entered. If true - enters exodus mode and emits ExodusMode event.
    /// @dev Exodus mode must be entered in case of current ethereum block number is higher than the oldest
    /// @dev of existed priority requests expiration block number.
    /// @return bool flag that is true if the Exodus mode must be entered.
    function activateDesertMode() public returns (bool) {
        // #if EASY_EXODUS
        bool trigger = true;
        // #else
        bool trigger = block.number >= priorityRequests[firstPriorityRequestId].expirationBlock &&
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
        bytes32 _genesisStateHash
        ) = abi.decode(initializationParameters, (address, address, address, bytes32));

        verifier = ZecreyVerifier(_verifierAddress);
        governance = Governance(_governanceAddress);
        additionalZecreyLegend = AdditionalZecreyLegend(_additionalZecreylegend);

        BlockHeader memory zeroBlockHeader = BlockHeader(
            0,
            0,
            EMPTY_STRING_KECCAK,
            0,
            _genesisStateHash,
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

    /// @notice Deposit Native Assets to Layer 2 - transfer ether from user into contract, validate it, register deposit
    /// @param _accountNameHash The receiver Layer 2 account name
    function depositBNB(bytes32 _accountNameHash) external payable {
        require(msg.value != 0, "ia");
        requireActive();
        registerDeposit(0, SafeCast.toUint128(msg.value), _accountNameHash);
    }

    /// @notice Deposit or Lock ERC20 token to Layer 2 - transfer ERC20 tokens from user into contract, validate it, register deposit
    /// @param _token Token address
    /// @param _amount Token amount
    /// @param _accountName Receiver Layer 2 account name
    function depositBEP20(
        IERC20 _token,
        uint104 _amount,
        bytes32 _accountName
    ) external nonReentrant {
        require(_amount != 0, "ia");
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

        registerDeposit(assetId, depositAmount, _accountName);
    }

    /// @notice Deposit NFT to Layer 2, both ERC721 and ERC1155 is supported
    // TODO maybe support ERC1155
    function depositERC721(
        bytes32 _accountNameHash,
        address _tokenAddress,
        uint256 _nftTokenId
    ) external nonReentrant {
        // not desert mode
        requireActive();
        // Transfer the tokens to this contract
        bool success = Utils.transferFromERC721(msg.sender, address(this), _tokenAddress, _nftTokenId);

        require(success, "nft transfer failure");

        // Priority Queue request
        TxTypes.DepositERC721 memory tx = TxTypes.DepositERC721({
        txType : uint8(TxTypes.TxType.DepositERC721),
        accountNameHash : _accountNameHash,
        tokenAddress : _tokenAddress,
        nftTokenId : _nftTokenId
        });
        // compact pub data
        bytes memory pubData = TxTypes.writeDepositERC721PubdataForPriorityQueue(tx);

        // add into priority request queue
        addPriorityRequest(TxTypes.TxType.DepositERC721, pubData);

        emit DepositERC721(_accountNameHash, _tokenAddress, _nftTokenId);
    }

    // TODO
    function withdrawERC721(
        bytes32 _accountNameHash,
        address _tokenAddress,
        address _minter,
        uint256 _nftTokenId
    ) internal nonReentrant {
        bool success;
        if (_minter == _tokenAddress) {
            /// This is a NFT from layer 1, withdraw id directly
            success = Utils.transferFromERC721(address(this), msg.sender, _tokenAddress, _nftTokenId);
        } else {
            /// This is a NFT from layer 2
            // TODO
            //            success = mintFromL2(msg.sender, _tokenAddress, _nftID, _amount, _minter, _extraData);
        }

        require(success, "nft transfer failure");

        // TODO
        //        emit WithdrawNFT(msg.sender, _accountNameHash, _tokenAddress, _minter, uint8(_nftType), _nftID, _amount);
    }

    function mintFromL2(
        address _to,
        address _tokenAddress,
        uint256 _nftID,
        uint32 _amount,
        address _minter,
        bytes memory _extraData
    ) internal returns (bool success) {
        if (_amount == 0) return true;

        try IL2MintableNFT(_tokenAddress).mintFromL2(
            _to,
            _nftID,
            _amount,
            _minter,
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
            require(success, "d");
            // Native Asset withdraw failed
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

    /// @notice Compute onchain operations hash
    /// @param _onchainOpsPubData The public data of onchain operations
    function computeOnchainOpsHash(bytes memory _onchainOpsPubData) public pure returns (bytes32 onchainOpsDataHash){
        return keccak256(_onchainOpsPubData);
    }

    /// @dev Process one block commit using previous block BlockHeader,
    /// @dev returns new block BlockHeader
    function commitOneBlock(BlockHeader memory _previousBlock, CommitBlockInfo memory _newBlock)
    internal
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
                TxTypes.Withdraw memory tx = TxTypes.readWithdrawPubdata(pubData);
                // Circuit guarantees that partial exits are available only for fungible tokens
                require(tx.assetId <= MAX_FUNGIBLE_ASSET_ID, "mf1");
                withdrawOrStore(uint16(tx.assetId), tx.toAddress, tx.assetAmount);
            } else if (txType == TxTypes.TxType.FullExit) {
                // TODO get layer-1 address by account name
                address toAddress = address(0x00);
                TxTypes.FullExit memory tx = TxTypes.readFullExitPubdata(pubData);
                require(tx.assetId <= MAX_FUNGIBLE_ASSET_ID, "mf1");
                withdrawOrStore(uint16(tx.assetId), toAddress, tx.assetAmount);
            } else if (txType == TxTypes.TxType.FullExitNFT) {
                // TODO get layer-1 address by account name
                address toAddress = address(0x00);
                // TODO check params for NFT address
                TxTypes.FullExitNFT memory tx = TxTypes.readFullExitNFTPubdata(pubData);
                // TODO withdraw NFT, minter
                withdrawERC721(tx.accountNameHash, tx.nftAddress, tx.nftAddress, tx.nftTokenId);
            } else if (txType == TxTypes.TxType.WithdrawNFT) {
                TxTypes.WithdrawNFT memory tx = TxTypes.readWithdrawNFTPubdata(pubData);
                // TODO withdraw NFT
                //                withdrawERC721(tx.accountNameHash, tx.toAddress, tx.nftAddress, tx.nftTokenId);
            } else {
                // unsupported tx in block verification
                revert("l");
            }

            pendingOnchainOpsHash = Utils.concatHash(pendingOnchainOpsHash, pubData);
        }
        // incorrect onchain txs executed
        require(pendingOnchainOpsHash == _block.blockHeader.pendingOnchainOperationsHash, "m");
    }

    /// @notice Verify layer-2 blocks proofs
    /// @param _blocks Verified blocks info
    function verifyBlocks(VerifyBlockInfo[] memory _blocks, uint256[] memory _proofs) external nonReentrant {
        requireActive();
        governance.requireActiveValidator(msg.sender);
        uint32 currentTotalBlocksVerified = totalBlocksVerified;

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
            try this._transferERC20{gas : config.WITHDRAWAL_GAS_LIMIT()}(IERC20(tokenAddr), _recipient, _amount, _amount) {
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
        TxTypes.Deposit memory tx = TxTypes.Deposit({
        txType : uint8(TxTypes.TxType.Deposit),
        accountIndex : 0, // unknown at the moment
        accountNameHash : _accountNameHash,
        assetId : _assetId,
        amount : _amount
        });
        // compact pub data
        bytes memory pubData = TxTypes.writeDepositPubdataForPriorityQueue(tx);
        // add into priority request queue
        addPriorityRequest(TxTypes.TxType.Deposit, pubData);
        emit Deposit(_assetId, _accountNameHash, _amount);
    }

    /// @notice Saves priority request in storage
    /// @dev Calculates expiration block for request, store this request and emit NewPriorityRequest event
    /// @param _txType Rollup tx type
    /// @param _pubData tx pub data
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
                    // unsupported tx
                    revert("F");
                }
                processableOperationsHash = Utils.concatHash(processableOperationsHash, txPubData);
            }
        }
    }

    /// @notice Checks that register zns is same as tx in priority queue
    /// @param _registerZNS register zns
    /// @param _priorityRequestId tx's id in priority queue
    function checkPriorityOperation(TxTypes.RegisterZNS memory _registerZNS, uint64 _priorityRequestId) internal view {
        TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
        // incorrect priority tx type
        require(priorReqType == TxTypes.TxType.RegisterZNS, "H");

        bytes20 hashedPubdata = priorityRequests[_priorityRequestId].hashedPubData;
        require(TxTypes.checkRegisterZNSInPriorityQueue(_registerZNS, hashedPubdata), "I");
    }

    /// @notice Checks that deposit is same as tx in priority queue
    /// @param _deposit Deposit data
    /// @param _priorityRequestId tx's id in priority queue
    function checkPriorityOperation(TxTypes.Deposit memory _deposit, uint64 _priorityRequestId) internal view {
        TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
        // incorrect priority tx type
        require(priorReqType == TxTypes.TxType.Deposit, "H");

        bytes20 hashedPubdata = priorityRequests[_priorityRequestId].hashedPubData;
        require(TxTypes.checkDepositInPriorityQueue(_deposit, hashedPubdata), "I");
    }

    /// @notice Checks that FullExit is same as tx in priority queue
    /// @param _fullExit FullExit data
    /// @param _priorityRequestId tx's id in priority queue
    function checkPriorityOperation(TxTypes.FullExit memory _fullExit, uint64 _priorityRequestId) internal view {
        TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
        // incorrect priority tx type
        require(priorReqType == TxTypes.TxType.FullExit, "J");

        bytes20 hashedPubdata = priorityRequests[_priorityRequestId].hashedPubData;
        require(TxTypes.checkFullExitInPriorityQueue(_fullExit, hashedPubdata), "K");
    }

    /// @notice Checks that FullExitNFT is same as tx in priority queue
    /// @param _fullExitNFT FullExit nft data
    /// @param _priorityRequestId tx's id in priority queue
    function checkPriorityOperation(TxTypes.FullExitNFT memory _fullExitNFT, uint64 _priorityRequestId) internal view {
        TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
        // incorrect priority tx type
        require(priorReqType == TxTypes.TxType.FullExitNFT, "J");


        bytes20 hashedPubdata = priorityRequests[_priorityRequestId].hashedPubData;
        require(TxTypes.checkFullExitNFTInPriorityQueue(_fullExitNFT, hashedPubdata), "K");
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
        (bool callSuccess,) = _to.call{gas : config.WITHDRAWAL_GAS_LIMIT(), value : _amount}("");
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
