// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.0;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./SafeMathUInt128.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./Utils.sol";

import "./Storage.sol";
import "./Config.sol";
import "./Events.sol";

import "./Bytes.sol";
import "./TxTypes.sol";

import "./UpgradeableMaster.sol";

/// @title Zkbas additional main contract
/// @author Zkbas
contract AdditionalZkbas is Storage, Config, Events, ReentrancyGuard, IERC721Receiver {
    using SafeMath for uint256;
    using SafeMathUInt128 for uint128;

    function increaseBalanceToWithdraw(bytes22 _packedBalanceKey, uint128 _amount) internal {
        uint128 balance = pendingBalances[_packedBalanceKey].balanceToWithdraw;
        pendingBalances[_packedBalanceKey] = PendingBalance(balance.add(_amount), FILLED_GAS_RESERVE_VALUE);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4){
        return this.onERC721Received.selector;
    }

    /*
        StateRoot
            AccountRoot
            NftRoot
        Account
            AccountIndex
            AccountNameHash bytes32
            PublicKey
            AssetRoot
            LiquidityRoot
        Asset
           AssetId
           Balance
        Nft
    */
    function performDesert(
        StoredBlockInfo memory _storedBlockInfo,
        address _owner,
        uint32 _accountId,
        uint32 _tokenId,
        uint128 _amount
    ) external {
        require(_accountId <= MAX_ACCOUNT_INDEX, "e");
        require(_accountId != SPECIAL_ACCOUNT_ID, "v");

        require(desertMode, "s");
        // must be in exodus mode
        require(!performedDesert[_accountId][_tokenId], "t");
        // already exited
        require(storedBlockHashes[totalBlocksVerified] == hashStoredBlockInfo(_storedBlockInfo), "u");
        // incorrect stored block info

        // TODO
        //        bool proofCorrect = verifier.verifyExitProof(
        //            _storedBlockHeader.accountRoot,
        //            _accountId,
        //            _owner,
        //            _tokenId,
        //            _amount,
        //            _nftCreatorAccountId,
        //            _nftCreatorAddress,
        //            _nftSerialId,
        //            _nftContentHash,
        //            _proof
        //        );
        //        require(proofCorrect, "x");

        if (_tokenId <= MAX_FUNGIBLE_ASSET_ID) {
            bytes22 packedBalanceKey = packAddressAndAssetId(_owner, uint16(_tokenId));
            increaseBalanceToWithdraw(packedBalanceKey, _amount);
        } else {
            // TODO
            require(_amount != 0, "Z");
            // Unsupported nft amount
            //            TxTypes.WithdrawNFT memory withdrawNftOp = TxTypes.WithdrawNFT({
            //            txType : uint8(TxTypes.TxType.WithdrawNFT),
            //            accountIndex : _nftCreatorAccountId,
            //            toAddress : _nftCreatorAddress,
            //            proxyAddress : _nftCreatorAddress,
            //            nftAssetId : _nftSerialId,
            //            gasFeeAccountIndex : 0,
            //            gasFeeAssetId : 0,
            //            gasFeeAssetAmount : 0
            //            });
            //            pendingWithdrawnNFTs[_tokenId] = withdrawNftOp;
            //            emit WithdrawalNFTPending(_tokenId);
        }
        performedDesert[_accountId][_tokenId] = true;
    }

    function cancelOutstandingDepositsForExodusMode(uint64 _n, bytes[] memory _depositsPubData) external {
        require(desertMode, "8");
        // exodus mode not active
        uint64 toProcess = Utils.minU64(totalOpenPriorityRequests, _n);
        require(toProcess > 0, "9");
        // no deposits to process
        uint64 currentDepositIdx = 0;
        for (uint64 id = firstPriorityRequestId; id < firstPriorityRequestId + toProcess; id++) {
            if (priorityRequests[id].txType == TxTypes.TxType.Deposit) {
                bytes memory depositPubdata = _depositsPubData[currentDepositIdx];
                require(Utils.hashBytesToBytes20(depositPubdata) == priorityRequests[id].hashedPubData, "a");
                ++currentDepositIdx;

                // TODO get address by account name
                address owner = address(0x0);
                TxTypes.Deposit memory _tx = TxTypes.readDepositPubData(depositPubdata);
                bytes22 packedBalanceKey = packAddressAndAssetId(owner, uint16(_tx.assetId));
                pendingBalances[packedBalanceKey].balanceToWithdraw += _tx.amount;
            }
            delete priorityRequests[id];
        }
        firstPriorityRequestId += toProcess;
        totalOpenPriorityRequests -= toProcess;
    }

    // TODO
    uint256 internal constant SECURITY_COUNCIL_2_WEEKS_THRESHOLD = 3;
    uint256 internal constant SECURITY_COUNCIL_1_WEEK_THRESHOLD = 2;
    uint256 internal constant SECURITY_COUNCIL_3_DAYS_THRESHOLD = 1;

    function cutUpgradeNoticePeriod() external {
        requireActive();

        address payable[SECURITY_COUNCIL_MEMBERS_NUMBER] memory SECURITY_COUNCIL_MEMBERS = [
        payable(0x00), payable(0x00), payable(0x00)
        ];
        for (uint256 id = 0; id < SECURITY_COUNCIL_MEMBERS_NUMBER; ++id) {
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

    /// @notice Reverts unverified blocks
    function revertBlocks(StoredBlockInfo[] memory _blocksToRevert) external {
        requireActive();

        governance.requireActiveValidator(msg.sender);

        uint32 blocksCommitted = totalBlocksCommitted;
        uint32 blocksToRevert = Utils.minU32(uint32(_blocksToRevert.length), blocksCommitted - totalBlocksVerified);
        uint64 revertedPriorityRequests = 0;

        for (uint32 i = 0; i < blocksToRevert; ++i) {
            StoredBlockInfo memory storedBlockInfo = _blocksToRevert[i];
            require(storedBlockHashes[blocksCommitted] == hashStoredBlockInfo(storedBlockInfo), "r");
            // incorrect stored block info

            delete storedBlockHashes[blocksCommitted];

            --blocksCommitted;
            revertedPriorityRequests += storedBlockInfo.priorityOperations;
        }

        totalBlocksCommitted = blocksCommitted;
        totalCommittedPriorityRequests -= revertedPriorityRequests;
        if (totalBlocksCommitted < totalBlocksVerified) {
            totalBlocksVerified = totalBlocksCommitted;
        }

        emit BlocksRevert(totalBlocksVerified, blocksCommitted);
    }

    function createPair(address _tokenA, address _tokenB) external {
        // Only governor can create token pair
        governance.requireGovernor(msg.sender);
        require(_tokenA != _tokenB, 'ia1');
        requireActive();
        (address _token0, address _token1) = _tokenA < _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
        // Get asset id by its address
        uint16 assetAId = 0;
        uint16 assetBId;
        if (_token0 != address(0)) {
            assetAId = governance.validateAssetAddress(_token0);
        }
        require(!governance.pausedAssets(assetAId), "ia2");
        assetBId = governance.validateAssetAddress(_token1);
        require(!governance.pausedAssets(assetBId), "ia3");
        (assetAId, assetBId) = assetAId < assetBId ? (assetAId, assetBId) : (assetBId, assetAId);

        // Check asset exist
        require(!isTokenPairExist[assetAId][assetBId], 'ip');

        // Create token pair
        governance.validateAssetTokenLister(msg.sender);
        // new token pair index
        isTokenPairExist[assetAId][assetBId] = true;
        tokenPairs[assetAId][assetBId] = totalTokenPairs;

        // Priority Queue request
        TxTypes.CreatePair memory _tx = TxTypes.CreatePair({
        txType : uint8(TxTypes.TxType.CreatePair),
        pairIndex : totalTokenPairs,
        assetAId : assetAId,
        assetBId : assetBId,
        feeRate : governance.assetGovernance().feeRate(),
        treasuryAccountIndex : governance.assetGovernance().treasuryAccountIndex(),
        treasuryRate : governance.assetGovernance().treasuryRate()
        });
        // compact pub data
        bytes memory pubData = TxTypes.writeCreatePairPubDataForPriorityQueue(_tx);
        // add into priority request queue
        addPriorityRequest(TxTypes.TxType.CreatePair, pubData);
        totalTokenPairs++;

        emit CreateTokenPair(_tx.pairIndex, assetAId, assetBId, _tx.feeRate, _tx.treasuryAccountIndex, _tx.treasuryRate);
    }

    struct PairInfo {
        address tokenA;
        address tokenB;
        uint16 feeRate;
        uint32 treasuryAccountIndex;
        uint16 treasuryRate;
    }

    function updatePairRate(PairInfo memory _pairInfo) external {
        // Only governor can update token pair
        governance.requireGovernor(msg.sender);
        requireActive();
        (address _token0, address _token1) = _pairInfo.tokenA < _pairInfo.tokenB ? (_pairInfo.tokenA, _pairInfo.tokenB) : (_pairInfo.tokenB, _pairInfo.tokenA);
        // Get asset id by its address
        uint16 assetAId = 0;
        uint16 assetBId;
        if (_token0 != address(0)) {
            assetAId = governance.validateAssetAddress(_token0);
        }
        require(!governance.pausedAssets(assetAId), "ia2");
        assetBId = governance.validateAssetAddress(_token1);
        require(!governance.pausedAssets(assetBId), "ia3");
        (assetAId, assetBId) = assetAId < assetBId ? (assetAId, assetBId) : (assetBId, assetAId);
        require(isTokenPairExist[assetAId][assetBId], 'pne');

        uint16 _pairIndex = tokenPairs[assetAId][assetBId];

        // Priority Queue request
        TxTypes.UpdatePairRate memory _tx = TxTypes.UpdatePairRate({
        txType : uint8(TxTypes.TxType.UpdatePairRate),
        pairIndex : _pairIndex,
        feeRate : _pairInfo.feeRate,
        treasuryAccountIndex : _pairInfo.treasuryAccountIndex,
        treasuryRate : _pairInfo.treasuryRate
        });
        // compact pub data
        bytes memory pubData = TxTypes.writeUpdatePairRatePubDataForPriorityQueue(_tx);
        // add into priority request queue
        addPriorityRequest(TxTypes.TxType.UpdatePairRate, pubData);

        emit UpdateTokenPair(_pairIndex, _pairInfo.feeRate, _pairInfo.treasuryAccountIndex, _pairInfo.treasuryRate);
    }

    /// @notice Set default factory for our contract. This factory will be used to mint an NFT token that has no factory
    /// @param _factory Address of NFT factory
    function setDefaultNFTFactory(NFTFactory _factory) external {
        governance.requireGovernor(msg.sender);
        require(address(_factory) != address(0), "mb1");
        // Factory should be non zero
        require(address(defaultNFTFactory) == address(0), "mb2");
        // NFTFactory is already set
        defaultNFTFactory = address(_factory);
        emit NewDefaultNFTFactory(address(_factory));
    }

    /// @notice Register NFTFactory to this contract
    /// @param _creatorAccountName accountName of the creator
    /// @param _collectionId collection Id of the NFT related to this creator
    /// @param _factory NFT Factory
    function registerNFTFactory(
        string calldata _creatorAccountName,
        uint32 _collectionId,
        NFTFactory _factory
    ) external {
        bytes32 creatorAccountNameHash = znsController.getSubnodeNameHash(_creatorAccountName);
        require(znsController.isRegisteredNameHash(creatorAccountNameHash), "nr");
        require(address(nftFactories[creatorAccountNameHash][_collectionId]) == address(0), "Q");
        // Check check accountNameHash belongs to msg.sender
        address creatorAddress = getAddressByAccountNameHash(creatorAccountNameHash);
        require(creatorAddress == msg.sender, 'ns');

        nftFactories[creatorAccountNameHash][_collectionId] = address(_factory);
        emit NewNFTFactory(creatorAccountNameHash, _collectionId, address(_factory));
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

    function getAddressByAccountNameHash(bytes32 accountNameHash) public view returns (address){
        return znsController.getOwner(accountNameHash);
    }

    /// @notice Register full exit request - pack pubdata, add priority request
    /// @param _accountName account name
    /// @param _asset Token address, 0 address for BNB
    function requestFullExit(string calldata _accountName, address _asset) public {
        requireActive();
        bytes32 accountNameHash = znsController.getSubnodeNameHash(_accountName);
        require(znsController.isRegisteredNameHash(accountNameHash), "nr");
        // get address by account name hash
        address creatorAddress = getAddressByAccountNameHash(accountNameHash);
        require(msg.sender == creatorAddress, "ia");

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
        accountNameHash : accountNameHash,
        assetId : assetId,
        assetAmount : 0 // unknown at this point
        });
        bytes memory pubData = TxTypes.writeFullExitPubDataForPriorityQueue(_tx);
        addPriorityRequest(TxTypes.TxType.FullExit, pubData);

        // User must fill storage slot of balancesToWithdraw(msg.sender, tokenId) with nonzero value
        // In this case operator should just overwrite this slot during confirming withdrawal
        bytes22 packedBalanceKey = packAddressAndAssetId(msg.sender, assetId);
        pendingBalances[packedBalanceKey].gasReserveValue = FILLED_GAS_RESERVE_VALUE;
    }

    /// @notice Register full exit nft request - pack pubdata, add priority request
    /// @param _accountName account name
    /// @param _nftIndex account NFT index in zkbas network
    function requestFullExitNft(string calldata _accountName, uint32 _nftIndex) public {
        requireActive();
        bytes32 accountNameHash = znsController.getSubnodeNameHash(_accountName);
        require(znsController.isRegisteredNameHash(accountNameHash), "nr");
        require(_nftIndex < MAX_NFT_INDEX, "T");
        // get address by account name hash
        address creatorAddress = getAddressByAccountNameHash(accountNameHash);
        require(msg.sender == creatorAddress, "ia");

        // Priority Queue request
        TxTypes.FullExitNft memory _tx = TxTypes.FullExitNft({
        txType : uint8(TxTypes.TxType.FullExitNft),
        accountIndex : 0, // unknown
        creatorAccountIndex : 0, // unknown
        creatorTreasuryRate : 0,
        nftIndex : _nftIndex,
        collectionId : 0, // unknown
        nftL1Address : address(0x0), // unknown
        accountNameHash : accountNameHash,
        creatorAccountNameHash : bytes32(0),
        nftContentHash : bytes32(0x0), // unknown,
        nftL1TokenId : 0 // unknown
        });
        bytes memory pubData = TxTypes.writeFullExitNftPubDataForPriorityQueue(_tx);
        addPriorityRequest(TxTypes.TxType.FullExitNft, pubData);
    }

    /// @notice Deposit NFT to Layer 2, ERC721 is supported
    //    function depositNft(
    //        string calldata _accountName,
    //        address _nftL1Address,
    //        uint256 _nftL1TokenId
    //    ) external {
    //        requireActive();
    //        bytes32 accountNameHash = znsController.getSubnodeNameHash(_accountName);
    //        require(znsController.isRegisteredNameHash(accountNameHash), "nr");
    //        // Transfer the tokens to this contract
    //        bool success;
    //        try IERC721(_nftL1Address).safeTransferFrom(
    //            msg.sender,
    //            address(this),
    //            _nftL1TokenId
    //        ){
    //            success = true;
    //        }catch{
    //            success = false;
    //        }
    //        require(success, "ntf");
    //        // check owner
    //        require(IERC721(_nftL1Address).ownerOf(_nftL1TokenId) == address(this), "i");
    //
    //        // check if the nft is mint from layer-2
    //        bytes32 nftKey = keccak256(abi.encode(_nftL1Address, _nftL1TokenId));
    //        uint16 collectionId = 0;
    //        uint40 nftIndex = 0;
    //        uint32 creatorAccountIndex = 0;
    //        uint16 creatorTreasuryRate = 0;
    //        bytes32 nftContentHash;
    //        if (l2Nfts[nftKey].nftContentHash == bytes32(0)) {
    //            // it means this is a new layer-1 nft
    //            nftContentHash = nftKey;
    //        } else {
    //            // it means this is a nft that comes from layer-2
    //            nftContentHash = l2Nfts[nftKey].nftContentHash;
    //            collectionId = l2Nfts[nftKey].collectionId;
    //            nftIndex = l2Nfts[nftKey].nftIndex;
    //            creatorAccountIndex = l2Nfts[nftKey].creatorAccountIndex;
    //            creatorTreasuryRate = l2Nfts[nftKey].creatorTreasuryRate;
    //        }
    //
    //        TxTypes.DepositNft memory _tx = TxTypes.DepositNft({
    //        txType : uint8(TxTypes.TxType.DepositNft),
    //        accountIndex : 0, // unknown at this point
    //        nftIndex : nftIndex,
    //        nftL1Address : _nftL1Address,
    //        creatorAccountIndex : creatorAccountIndex,
    //        creatorTreasuryRate : creatorTreasuryRate,
    //        nftContentHash : nftContentHash,
    //        nftL1TokenId : _nftL1TokenId,
    //        accountNameHash : accountNameHash,
    //        collectionId : collectionId
    //        });
    //
    //        // compact pub data
    //        bytes memory pubData = TxTypes.writeDepositNftPubDataForPriorityQueue(_tx);
    //
    //        // add into priority request queue
    //        addPriorityRequest(TxTypes.TxType.DepositNft, pubData);
    //
    //        emit DepositNft(accountNameHash, nftContentHash, _nftL1Address, _nftL1TokenId, collectionId);
    //    }

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

    event NewZkbasVerifier(address verifier);

    bytes32 private constant EMPTY_STRING_KECCAK = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    struct CommitBlockInfo {
        bytes32 newStateRoot;
        bytes publicData;
        uint256 timestamp;
        uint32[] publicDataOffsets;
        uint32 blockNumber;
        uint16 blockSize;
    }

    function commitBlocks(
        StoredBlockInfo memory _lastCommittedBlockData,
        CommitBlockInfo[] memory _newBlocksData
    )
    external
    {
        requireActive();
        governance.requireActiveValidator(msg.sender);
        // Check that we commit blocks after last committed block
        // incorrect previous block data
        require(storedBlockHashes[totalBlocksCommitted] == hashStoredBlockInfo(_lastCommittedBlockData), "i");

        for (uint32 i = 0; i < _newBlocksData.length; ++i) {
            _lastCommittedBlockData = commitOneBlock(_lastCommittedBlockData, _newBlocksData[i]);

            totalCommittedPriorityRequests += _lastCommittedBlockData.priorityOperations;
            storedBlockHashes[_lastCommittedBlockData.blockNumber] = hashStoredBlockInfo(_lastCommittedBlockData);

            emit BlockCommit(_lastCommittedBlockData.blockNumber);
        }

        totalBlocksCommitted += uint32(_newBlocksData.length);

        require(totalCommittedPriorityRequests <= totalOpenPriorityRequests, "j");
    }
    // @dev This function is only for test
    // TODO delete this function
    function updateZkbasVerifier(address _newVerifierAddress) external {
        verifier = ZkbasVerifier(_newVerifierAddress);
        emit NewZkbasVerifier(_newVerifierAddress);
    }

    /// @dev Process one block commit using previous block StoredBlockInfo,
    /// @dev returns new block StoredBlockInfo
    function commitOneBlock(StoredBlockInfo memory _previousBlock, CommitBlockInfo memory _newBlock)
    internal
    view
    returns (StoredBlockInfo memory storedNewBlock)
    {
        // only commit next block
        require(_newBlock.blockNumber == _previousBlock.blockNumber + 1, "f");

        // Check timestamp of the new block
        // Block should be after previous block
        {
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
        StoredBlockInfo(
            _newBlock.blockSize,
            _newBlock.blockNumber,
            priorityReqCommitted,
            pendingOnchainOpsHash,
            _newBlock.timestamp,
            _newBlock.newStateRoot,
            commitment
        );
    }

    function createBlockCommitment(
        StoredBlockInfo memory _previousBlock,
        CommitBlockInfo memory _newBlockData
    ) internal view returns (bytes32) {
        uint256[] memory pubData = Utils.bytesToUint256Arr(_newBlockData.publicData);
        bytes32 converted = keccak256(abi.encodePacked(
                uint256(_newBlockData.blockNumber), // block number
                uint256(_newBlockData.timestamp), // time stamp
                _previousBlock.stateRoot, // old state root
                _newBlockData.newStateRoot, // new state root
                pubData, // pub data
                uint256(_newBlockData.publicDataOffsets.length) // on chain ops count
            ));
        return converted;
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

        require(pubData.length % TX_SIZE == 0, "A");

        uint64 uncommittedPriorityRequestsOffset = firstPriorityRequestId + totalCommittedPriorityRequests;
        priorityOperationsProcessed = 0;
        processableOperationsHash = EMPTY_STRING_KECCAK;

        for (uint16 i = 0; i < _newBlockData.publicDataOffsets.length; ++i) {
            uint32 pubdataOffset = _newBlockData.publicDataOffsets[i];
            require(pubdataOffset < pubData.length, "B");

            TxTypes.TxType txType = TxTypes.TxType(uint8(pubData[pubdataOffset]));

            if (txType == TxTypes.TxType.RegisterZNS) {
                bytes memory txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_TX_PUBDATA_BYTES);

                TxTypes.RegisterZNS memory registerZNSData = TxTypes.readRegisterZNSPubData(txPubData);
                checkPriorityOperation(registerZNSData, uncommittedPriorityRequestsOffset + priorityOperationsProcessed);
                priorityOperationsProcessed++;
            } else if (txType == TxTypes.TxType.CreatePair) {
                bytes memory txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_TX_PUBDATA_BYTES);

                TxTypes.CreatePair memory createPairData = TxTypes.readCreatePairPubData(txPubData);
                checkPriorityOperation(createPairData, uncommittedPriorityRequestsOffset + priorityOperationsProcessed);
                priorityOperationsProcessed++;
            } else if (txType == TxTypes.TxType.UpdatePairRate) {
                bytes memory txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_TX_PUBDATA_BYTES);

                TxTypes.UpdatePairRate memory updatePairData = TxTypes.readUpdatePairRatePubData(txPubData);
                checkPriorityOperation(updatePairData, uncommittedPriorityRequestsOffset + priorityOperationsProcessed);
                priorityOperationsProcessed++;
            } else if (txType == TxTypes.TxType.Deposit) {
                bytes memory txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_TX_PUBDATA_BYTES);
                TxTypes.Deposit memory depositData = TxTypes.readDepositPubData(txPubData);
                checkPriorityOperation(depositData, uncommittedPriorityRequestsOffset + priorityOperationsProcessed);
                priorityOperationsProcessed++;
            } else if (txType == TxTypes.TxType.DepositNft) {
                bytes memory txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_TX_PUBDATA_BYTES);

                TxTypes.DepositNft memory depositNftData = TxTypes.readDepositNftPubData(txPubData);
                checkPriorityOperation(depositNftData, uncommittedPriorityRequestsOffset + priorityOperationsProcessed);
                priorityOperationsProcessed++;
            } else {

                bytes memory txPubData;

                if (txType == TxTypes.TxType.Withdraw) {
                    txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_TX_PUBDATA_BYTES);
                } else if (txType == TxTypes.TxType.WithdrawNft) {
                    txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_TX_PUBDATA_BYTES);
                } else if (txType == TxTypes.TxType.FullExit) {
                    txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_TX_PUBDATA_BYTES);

                    TxTypes.FullExit memory fullExitData = TxTypes.readFullExitPubData(txPubData);

                    checkPriorityOperation(
                        fullExitData,
                        uncommittedPriorityRequestsOffset + priorityOperationsProcessed
                    );
                    priorityOperationsProcessed++;
                } else if (txType == TxTypes.TxType.FullExitNft) {
                    txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_TX_PUBDATA_BYTES);

                    TxTypes.FullExitNft memory fullExitNFTData = TxTypes.readFullExitNftPubData(txPubData);

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

    /// @notice Checks that update pair is same as _tx in priority queue
    /// @param _updatePairRate update pair
    /// @param _priorityRequestId _tx's id in priority queue
    function checkPriorityOperation(TxTypes.UpdatePairRate memory _updatePairRate, uint64 _priorityRequestId) internal view {
        TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
        // incorrect priority _tx type
        require(priorReqType == TxTypes.TxType.UpdatePairRate, "H");

        bytes20 hashedPubData = priorityRequests[_priorityRequestId].hashedPubData;
        require(TxTypes.checkUpdatePairRateInPriorityQueue(_updatePairRate, hashedPubData), "I");
    }

    /// @notice Checks that create pair is same as _tx in priority queue
    /// @param _createPair create pair
    /// @param _priorityRequestId _tx's id in priority queue
    function checkPriorityOperation(TxTypes.CreatePair memory _createPair, uint64 _priorityRequestId) internal view {
        TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
        // incorrect priority _tx type
        require(priorReqType == TxTypes.TxType.CreatePair, "H");

        bytes20 hashedPubData = priorityRequests[_priorityRequestId].hashedPubData;
        require(TxTypes.checkCreatePairInPriorityQueue(_createPair, hashedPubData), "I");
    }

    /// @notice Checks that register zns is same as _tx in priority queue
    /// @param _registerZNS register zns
    /// @param _priorityRequestId _tx's id in priority queue
    function checkPriorityOperation(TxTypes.RegisterZNS memory _registerZNS, uint64 _priorityRequestId) internal view {
        TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
        // incorrect priority _tx type
        require(priorReqType == TxTypes.TxType.RegisterZNS, "H");

        bytes20 hashedPubData = priorityRequests[_priorityRequestId].hashedPubData;
        require(TxTypes.checkRegisterZNSInPriorityQueue(_registerZNS, hashedPubData), "I");
    }

    /// @notice Checks that deposit is same as _tx in priority queue
    /// @param _deposit Deposit data
    /// @param _priorityRequestId _tx's id in priority queue
    function checkPriorityOperation(TxTypes.Deposit memory _deposit, uint64 _priorityRequestId) internal view {
        TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
        // incorrect priority _tx type
        require(priorReqType == TxTypes.TxType.Deposit, "H");

        bytes20 hashedPubData = priorityRequests[_priorityRequestId].hashedPubData;
        require(TxTypes.checkDepositInPriorityQueue(_deposit, hashedPubData), "I");
    }

    /// @notice Checks that deposit is same as _tx in priority queue
    /// @param _deposit Deposit data
    /// @param _priorityRequestId _tx's id in priority queue
    function checkPriorityOperation(TxTypes.DepositNft memory _deposit, uint64 _priorityRequestId) internal view {
        TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
        // incorrect priority _tx type
        require(priorReqType == TxTypes.TxType.DepositNft, "H");

        bytes20 hashedPubData = priorityRequests[_priorityRequestId].hashedPubData;
        require(TxTypes.checkDepositNftInPriorityQueue(_deposit, hashedPubData), "I");
    }

    /// @notice Checks that FullExit is same as _tx in priority queue
    /// @param _fullExit FullExit data
    /// @param _priorityRequestId _tx's id in priority queue
    function checkPriorityOperation(TxTypes.FullExit memory _fullExit, uint64 _priorityRequestId) internal view {
        TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
        // incorrect priority _tx type
        require(priorReqType == TxTypes.TxType.FullExit, "J");

        bytes20 hashedPubData = priorityRequests[_priorityRequestId].hashedPubData;
        require(TxTypes.checkFullExitInPriorityQueue(_fullExit, hashedPubData), "K");
    }

    /// @notice Checks that FullExitNFT is same as _tx in priority queue
    /// @param _fullExitNft FullExit nft data
    /// @param _priorityRequestId _tx's id in priority queue
    function checkPriorityOperation(TxTypes.FullExitNft memory _fullExitNft, uint64 _priorityRequestId) internal view {
        TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
        // incorrect priority _tx type
        require(priorReqType == TxTypes.TxType.FullExitNft, "J");

        bytes20 hashedPubData = priorityRequests[_priorityRequestId].hashedPubData;
        require(TxTypes.checkFullExitNftInPriorityQueue(_fullExitNft, hashedPubData), "K");
    }

}
