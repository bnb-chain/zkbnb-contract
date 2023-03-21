// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "./interfaces/Events.sol";
import "./lib/Utils.sol";
import "./lib/Bytes.sol";
import "./lib/TxTypes.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/INFTFactory.sol";
import "./Config.sol";
import "./Storage.sol";

/// @title ZkBNB main contract
/// @author ZkBNB Team
contract ZkBNB is Events, Storage, Config, ReentrancyGuardUpgradeable, IERC721Receiver {
  /// @notice Data needed to process onchain operation from block public data.
  /// @notice Onchain operations is operations that need some processing on L1: Deposits, Withdrawals, ChangePubKey.
  /// @param ethWitness Some external data that can be needed for operation processing
  /// @param publicDataOffset Byte offset in public data for onchain operation
  struct OnchainOperationData {
    bytes ethWitness;
    uint32 publicDataOffset;
  }

  struct CommitBlockInfo {
    bytes32 newStateRoot;
    bytes publicData;
    uint256 timestamp;
    OnchainOperationData[] onchainOperations;
    uint32 blockNumber;
    uint16 blockSize;
  }

  struct VerifyAndExecuteBlockInfo {
    StoredBlockInfo blockHeader;
    bytes[] pendingOnchainOpsPubData;
  }

  // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1052.md
  bytes32 private constant EMPTY_STRING_KECCAK = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

  function onERC721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external pure override returns (bytes4) {
    return this.onERC721Received.selector;
  }

  /// @notice ZkBNB contract initialization. Can be external because Proxy contract intercepts illegal calls of this function.
  /// @param initializationParameters Encoded representation of initialization parameters:
  /// @dev _governanceAddress The address of Governance contract
  /// @dev _verifierAddress The address of Verifier contract
  /// @dev _genesisStateHash Genesis blocks (first block) state tree root hash
  function initialize(bytes calldata initializationParameters) external initializer {
    __ReentrancyGuard_init();

    (address _governanceAddress, address _verifierAddress, address _additionalZkBNB, bytes32 _genesisStateRoot) = abi
      .decode(initializationParameters, (address, address, address, bytes32));

    verifier = ZkBNBVerifier(_verifierAddress);
    governance = Governance(_governanceAddress);
    additionalZkBNB = AdditionalZkBNB(_additionalZkBNB);

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

  /// @notice ZkBNB contract upgrade. Can be external because Proxy contract intercepts illegal calls of this function.
  /// @param upgradeParameters Encoded representation of upgrade parameters
  // solhint-disable-next-line no-empty-blocks
  function upgrade(bytes calldata upgradeParameters) external {
    address _additionalZkBNB = abi.decode(upgradeParameters, (address));
    if (_additionalZkBNB != address(0)) {
      additionalZkBNB = AdditionalZkBNB(_additionalZkBNB);
    }
  }

  /// @notice Deposit Native Assets to Layer 2 - transfer ether from user into contract, validate it, register deposit
  /// @param _to the receiver L1 address
  function depositBNB(address _to) external payable onlyActive {
    delegateAdditional();
  }

  /// @notice Deposit or Lock BEP20 token to Layer 2 - transfer ERC20 tokens from user into contract, validate it, register deposit
  /// @param _token Token address
  /// @param _amount Token amount
  /// @param _to the receiver L1 address
  function depositBEP20(IERC20 _token, uint104 _amount, address _to) external onlyActive {
    delegateAdditional();
  }

  /// @notice Deposit NFT to Layer 2, ERC721 is supported
  function depositNft(address _to, address _nftL1Address, uint256 _nftL1TokenId) external onlyActive {
    delegateAdditional();
  }

  /// @notice Register full exit request - pack pubdata, add priority request
  /// @param _accountIndex Numerical id of the account
  /// @param _asset Token address, 0 address for BNB
  function requestFullExit(uint32 _accountIndex, address _asset) public onlyActive {
    delegateAdditional();
  }

  /// @notice Register full exit nft request - pack pubdata, add priority request
  /// @param _accountIndex Numerical id of the account
  /// @param _nftIndex account NFT index in zkbnb network
  function requestFullExitNft(uint32 _accountIndex, uint32 _nftIndex) public onlyActive {
    delegateAdditional();
  }

  /// @notice  Withdraws NFT from zkSync contract to the owner
  /// @param _nftIndex Id of NFT token
  function withdrawPendingNFTBalance(uint40 _nftIndex) external {
    TxTypes.WithdrawNft memory op = pendingWithdrawnNFTs[_nftIndex];
    withdrawOrStoreNFT(op);
    delete pendingWithdrawnNFTs[_nftIndex];
  }

  /// @notice  Withdraws tokens from ZkBNB contract to the owner
  /// @param _owner Address of the tokens owner
  /// @param _token Address of tokens, zero address is used for Native Asset
  /// @param _amount Amount to withdraw to request.
  ///         NOTE: We will call ERC20.transfer(.., _amount), but if according to internal logic of ERC20 token ZkBNB contract
  ///         balance will be decreased by value more then _amount we will try to subtract this value from user pending balance
  function withdrawPendingBalance(address payable _owner, address _token, uint128 _amount) external {
    uint16 _assetId = 0;
    if (_token != address(0)) {
      _assetId = governance.validateAssetAddress(_token);
    }
    bytes22 packedBalanceKey = packAddressAndAssetId(_owner, _assetId);
    uint128 balance = pendingBalances[packedBalanceKey].balanceToWithdraw;
    uint128 amount = Utils.minU128(balance, _amount);
    if (_assetId == 0) {
      (bool success, ) = _owner.call{value: _amount}("");
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
    uint256 balanceDiff = balanceBefore - balanceAfter;
    //        require(balanceDiff > 0, "C");
    // transfer is considered successful only if the balance of the contract decreased after transfer
    require(balanceDiff <= _maxAmount, "7");
    // rollup balance difference (before and after transfer) is bigger than `_maxAmount`

    return SafeCast.toUint128(balanceDiff);
  }

  /// @notice Commit block
  /// @notice 1. Checks onchain operations, timestamp.

  function commitBlocks(
    StoredBlockInfo memory _lastCommittedBlockData,
    CommitBlockInfo[] memory _newBlocksData
  ) external onlyActive {
    governance.isActiveValidator(msg.sender);
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

  /// @dev Process one block commit using previous block StoredBlockInfo,
  /// @dev returns new block StoredBlockInfo
  function commitOneBlock(
    StoredBlockInfo memory _previousBlock,
    CommitBlockInfo memory _newBlock
  ) internal view returns (StoredBlockInfo memory storedNewBlock) {
    // only commit next block
    require(_newBlock.blockNumber == _previousBlock.blockNumber + 1, "f");

    // Check timestamp of the new block
    // Block should be after previous block
    {
      require(_newBlock.timestamp >= _previousBlock.timestamp, "g");
    }

    // padding zero transactions
    if (_newBlock.publicData.length < _newBlock.blockSize * TxTypes.PACKED_TX_PUBDATA_BYTES) {
      _newBlock.publicData = bytes.concat(
        _newBlock.publicData,
        new bytes(_newBlock.blockSize * TxTypes.PACKED_TX_PUBDATA_BYTES - _newBlock.publicData.length)
      );
    }

    // Check onchain operations
    (bytes32 pendingOnchainOpsHash, uint64 priorityReqCommitted) = collectOnchainOps(_newBlock);

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
  ) internal pure returns (bytes32) {
    // uint256[] memory pubData = Utils.bytesToUint256Arr(_newBlockData.publicData);
    bytes32 converted = keccak256(
      abi.encodePacked(
        uint256(_newBlockData.blockNumber), // block number
        uint256(_newBlockData.timestamp), // time stamp
        _previousBlock.stateRoot, // old state root
        _newBlockData.newStateRoot, // new state root
        _newBlockData.publicData, // pub data
        uint256(_newBlockData.onchainOperations.length) // on chain ops count
      )
    );
    return converted;
  }

  /// @notice Collect onchain ops and ensure it was not executed before
  function collectOnchainOps(
    CommitBlockInfo memory _newBlockData
  ) internal view returns (bytes32 processableOperationsHash, uint64 priorityOperationsProcessed) {
    bytes memory pubData = _newBlockData.publicData;

    require(pubData.length % TxTypes.PACKED_TX_PUBDATA_BYTES == 0, "A");

    uint64 uncommittedPriorityRequestsOffset = firstPriorityRequestId + totalCommittedPriorityRequests;
    priorityOperationsProcessed = 0;
    processableOperationsHash = EMPTY_STRING_KECCAK;

    for (uint16 i = 0; i < _newBlockData.onchainOperations.length; ++i) {
      uint32 pubdataOffset = _newBlockData.onchainOperations[i].publicDataOffset;
      require(pubdataOffset < pubData.length, "B");

      TxTypes.TxType txType = TxTypes.TxType(uint8(pubData[pubdataOffset]));

      if (txType == TxTypes.TxType.ChangePubKey) {
        bytes memory txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_TX_PUBDATA_BYTES);
        TxTypes.ChangePubKey memory changePubKeyData = TxTypes.readChangePubKeyPubData(txPubData);
        bytes memory ethWitness = _newBlockData.onchainOperations[i].ethWitness;
        require(ethWitness.length != 0, "signature should not be empty");
        bool valid = Utils.verifyChangePubkey(ethWitness, changePubKeyData);
        require(valid, "D"); // failed to verify change pubkey hash signature
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

          checkPriorityOperation(fullExitData, uncommittedPriorityRequestsOffset + priorityOperationsProcessed);
          priorityOperationsProcessed++;
        } else if (txType == TxTypes.TxType.FullExitNft) {
          txPubData = Bytes.slice(pubData, pubdataOffset, TxTypes.PACKED_TX_PUBDATA_BYTES);

          TxTypes.FullExitNft memory fullExitNFTData = TxTypes.readFullExitNftPubData(txPubData);

          checkPriorityOperation(fullExitNFTData, uncommittedPriorityRequestsOffset + priorityOperationsProcessed);
          priorityOperationsProcessed++;
        } else {
          // unsupported _tx
          revert("F");
        }
        processableOperationsHash = Utils.concatHash(processableOperationsHash, txPubData);
      }
    }
  }

  /// @notice Checks that deposit is same as _tx in priority queue
  /// @param _deposit Deposit data
  /// @param _priorityRequestId _tx's id in priority queue
  function checkPriorityOperation(TxTypes.Deposit memory _deposit, uint64 _priorityRequestId) internal view {
    TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
    // incorrect priority _tx type
    require(priorReqType == TxTypes.TxType.Deposit, "2H");

    bytes20 hashedPubData = priorityRequests[_priorityRequestId].hashedPubData;
    require(TxTypes.checkDepositInPriorityQueue(_deposit, hashedPubData), "2K");
  }

  /// @notice Checks that deposit is same as _tx in priority queue
  /// @param _depositNft Deposit data
  /// @param _priorityRequestId _tx's id in priority queue
  function checkPriorityOperation(TxTypes.DepositNft memory _depositNft, uint64 _priorityRequestId) internal view {
    TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
    // incorrect priority _tx type
    require(priorReqType == TxTypes.TxType.DepositNft, "3H");

    bytes20 hashedPubData = priorityRequests[_priorityRequestId].hashedPubData;
    require(TxTypes.checkDepositNftInPriorityQueue(_depositNft, hashedPubData), "3K");
  }

  /// @notice Checks that FullExit is same as _tx in priority queue
  /// @param _fullExit FullExit data
  /// @param _priorityRequestId _tx's id in priority queue
  function checkPriorityOperation(TxTypes.FullExit memory _fullExit, uint64 _priorityRequestId) internal view {
    TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
    // incorrect priority _tx type
    require(priorReqType == TxTypes.TxType.FullExit, "4H");

    bytes20 hashedPubData = priorityRequests[_priorityRequestId].hashedPubData;
    require(TxTypes.checkFullExitInPriorityQueue(_fullExit, hashedPubData), "4K");
  }

  /// @notice Checks that FullExitNFT is same as _tx in priority queue
  /// @param _fullExitNft FullExit nft data
  /// @param _priorityRequestId _tx's id in priority queue
  function checkPriorityOperation(TxTypes.FullExitNft memory _fullExitNft, uint64 _priorityRequestId) internal view {
    TxTypes.TxType priorReqType = priorityRequests[_priorityRequestId].txType;
    // incorrect priority _tx type
    require(priorReqType == TxTypes.TxType.FullExitNft, "5H");

    bytes20 hashedPubData = priorityRequests[_priorityRequestId].hashedPubData;
    require(TxTypes.checkFullExitNftInPriorityQueue(_fullExitNft, hashedPubData), "5K");
  }

  /// @notice Verify layer-2 blocks proofs
  /// @param _blocks Verified blocks info
  /// @param _proofs proofs
  function verifyAndExecuteBlocks(
    VerifyAndExecuteBlockInfo[] memory _blocks,
    uint256[] memory _proofs
  ) external onlyActive {
    governance.isActiveValidator(msg.sender);

    uint64 priorityRequestsExecuted = 0;
    uint32 nBlocks = uint32(_blocks.length);
    // proof public inputs
    for (uint16 i = 0; i < _blocks.length; ++i) {
      priorityRequestsExecuted += _blocks[i].blockHeader.priorityOperations;
      // update account root
      verifyAndExecuteOneBlock(_blocks[i], i);
      emit BlockVerification(_blocks[i].blockHeader.blockNumber);
    }
    uint256 numBlocksVerified = 0;
    bool[] memory blockVerified = new bool[](nBlocks);
    uint256[] memory batch = new uint256[](nBlocks);
    uint256 firstBlockSize = 0;
    while (numBlocksVerified < nBlocks) {
      // Find all blocks of the same type
      uint256 batchLength = 0;
      for (uint256 i = 0; i < nBlocks; i++) {
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
      uint256[] memory publicInputs = new uint256[](batchLength);
      uint256[] memory proofs = new uint256[](batchLength * 8);
      uint16 block_size = 0;
      uint256 q = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
      for (uint256 i = 0; i < batchLength; i++) {
        uint256 blockIdx = batch[i];
        blockVerified[blockIdx] = true;
        // verify block proof
        VerifyAndExecuteBlockInfo memory _block = _blocks[blockIdx];
        // Since the Solidity uint256 type can hold numbers larger than the snark scalar field order.
        // publicInputs must be less than B, otherwise there will be an out-of-bounds.
        // Same issue can be seen from https://github.com/0xPARC/zk-bug-tracker#semaphore-1
        publicInputs[i] = uint256(_block.blockHeader.commitment) % q;
        for (uint256 j = 0; j < 8; j++) {
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

  /// @notice Reverts unverified blocks
  function revertBlocks(StoredBlockInfo[] memory _blocksToRevert) external {
    delegateAdditional();
  }

  /// @notice Checks if Desert mode must be entered. If true - enters exodus mode and emits ExodusMode event.
  /// @dev Desert mode must be entered in case of current ethereum block number is higher than the oldest
  /// @dev of existed priority requests expiration block number.
  /// @return bool flag that is true if the Exodus mode must be entered.
  function activateDesertMode() public returns (bool) {
    // #if EASY_DESERT
    bool trigger = true;
    // #else
    trigger =
      block.number >= priorityRequests[firstPriorityRequestId].expirationBlock &&
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

  function withdrawOrStoreNFT(TxTypes.WithdrawNft memory op) internal {
    require(op.nftIndex <= MAX_NFT_INDEX, "invalid nft index");

    // get nft factory
    address _factoryAddress = governance.getNFTFactory(op.creatorAddress, op.collectionId);
    // store into l2 nfts
    bytes32 nftKey = keccak256(abi.encode(_factoryAddress, op.nftIndex));
    bool alreadyMintedFlag = false;
    if (mintedNfts[nftKey].nftContentHash != bytes32(0)) {
      alreadyMintedFlag = true;
    }
    // get layer-1 address by account name hash
    bytes memory _emptyExtraData;
    if (alreadyMintedFlag) {
      /// This is a NFT from layer 1, withdraw id directly
      try
        IERC721(_factoryAddress).safeTransferFrom{gas: WITHDRAWAL_NFT_GAS_LIMIT}(
          address(this),
          op.toAddress,
          op.nftIndex
        )
      {
        emit WithdrawNft(op.accountIndex, _factoryAddress, op.toAddress, op.nftIndex);
      } catch {
        storePendingNFT(op);
      }
    } else {
      try
        INFTFactory(_factoryAddress).mintFromZkBNB(
          op.creatorAddress,
          op.toAddress,
          op.nftIndex,
          governance.getNftTokenURI(op.nftContentType, op.nftContentHash),
          _emptyExtraData
        )
      {
        // register default collection factory
        governance.registerDefaultNFTFactory(op.creatorAddress, op.collectionId);

        mintedNfts[nftKey] = L2NftInfo({
          nftIndex: op.nftIndex,
          creatorAccountIndex: op.creatorAccountIndex,
          creatorTreasuryRate: op.creatorTreasuryRate,
          nftContentHash: op.nftContentHash,
          nftContentType: op.nftContentType,
          collectionId: uint16(op.collectionId)
        });
        emit WithdrawNft(op.accountIndex, _factoryAddress, op.toAddress, op.nftIndex);
      } catch {
        storePendingNFT(op);
      }
    }
  }

  /// @dev Save NFT as pending to withdraw
  function storePendingNFT(TxTypes.WithdrawNft memory op) internal {
    pendingWithdrawnNFTs[op.nftIndex] = op;
    emit WithdrawalNFTPending(op.nftIndex);
  }

  /// @notice Verify block index and proofs
  function verifyAndExecuteOneBlock(VerifyAndExecuteBlockInfo memory _block, uint32 _verifiedBlockIdx) internal {
    // Ensure block was committed
    require(
      hashStoredBlockInfo(_block.blockHeader) == storedBlockHashes[_block.blockHeader.blockNumber],
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
        withdrawOrStore(uint16(_tx.assetId), _tx.owner, _tx.assetAmount);
      } else if (txType == TxTypes.TxType.FullExitNft) {
        TxTypes.FullExitNft memory _tx = TxTypes.readFullExitNftPubData(pubData);
        // withdraw nft
        if (_tx.nftContentHash != bytes32(0)) {
          TxTypes.WithdrawNft memory _withdrawNftTx = TxTypes.WithdrawNft({
            accountIndex: _tx.accountIndex,
            creatorAccountIndex: _tx.creatorAccountIndex,
            creatorTreasuryRate: _tx.creatorTreasuryRate,
            nftIndex: _tx.nftIndex,
            collectionId: _tx.collectionId,
            toAddress: _tx.owner,
            creatorAddress: _tx.creatorAddress,
            nftContentHash: _tx.nftContentHash,
            nftContentType: _tx.nftContentType
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
  function withdrawOrStore(uint16 _assetId, address _recipient, uint128 _amount) internal {
    bytes22 packedBalanceKey = packAddressAndAssetId(_recipient, _assetId);

    bool sent = false;
    if (_assetId == 0) {
      sent = sendBNBNoRevert(payable(_recipient), _amount);
    } else {
      address tokenAddr = governance.assetAddresses(_assetId);
      // We use `_transferERC20` here to check that `ERC20` token indeed transferred `_amount`
      // and fail if token subtracted from ZkBNB balance more then `_amount` that was requested.
      // This can happen if token subtracts fee from sender while transferring `_amount` that was requested to transfer.
      try this.transferERC20{gas: WITHDRAWAL_GAS_LIMIT}(IERC20(tokenAddr), _recipient, _amount, _amount) {
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

  /// @notice Sends ETH
  /// @param _to Address of recipient
  /// @param _amount Amount of tokens to transfer
  /// @return bool flag indicating that transfer is successful
  function sendBNBNoRevert(address payable _to, uint256 _amount) internal returns (bool) {
    (bool callSuccess, ) = _to.call{gas: WITHDRAWAL_GAS_LIMIT, value: _amount}("");
    return callSuccess;
  }

  function increaseBalanceToWithdraw(bytes22 _packedBalanceKey, uint128 _amount) internal {
    uint128 balance = pendingBalances[_packedBalanceKey].balanceToWithdraw;
    pendingBalances[_packedBalanceKey] = PendingBalance(balance + _amount, FILLED_GAS_RESERVE_VALUE);
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
        return(ptr, size)
      }
    }
  }
}
