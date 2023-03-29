// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./lib/Utils.sol";

import "./Storage.sol";
import "./Config.sol";
import "./interfaces/Events.sol";

import "./lib/Bytes.sol";
import "./lib/TxTypes.sol";

/// @title ZkBNB additional main contract
/// @author ZkBNB
contract AdditionalZkBNB is Storage, Config, Events {
  function increaseBalanceToWithdraw(bytes22 _packedBalanceKey, uint128 _amount) internal {
    uint128 balance = pendingBalances[_packedBalanceKey].balanceToWithdraw;
    pendingBalances[_packedBalanceKey] = PendingBalance(balance + _amount, FILLED_GAS_RESERVE_VALUE);
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

  /// @notice Reverts unverified blocks
  function revertBlocks(StoredBlockInfo[] memory _blocksToRevert) external onlyActive {
    governance.isActiveValidator(msg.sender);

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

  /// @notice Deposit Native Assets to Layer 2 - transfer ether from user into contract, validate it, register deposit
  /// @param _to the receiver L1 address
  function depositBNB(address _to) external payable onlyActive {
    require(msg.value != 0, "ia");
    registerDeposit(0, SafeCast.toUint128(msg.value), _to);
  }

  /// @notice Deposit NFT to Layer 2, ERC721 is supported
  function depositNft(address _to, address _nftL1Address, uint256 _nftL1TokenId) external onlyActive {
    // check if the nft is mint from layer-2
    bytes32 nftKey = keccak256(abi.encode(_nftL1Address, _nftL1TokenId));
    require(mintedNfts[nftKey].nftContentHash != bytes32(0), "l1 nft is not allowed");

    // Transfer the tokens to this contract
    bool success;
    try IERC721(_nftL1Address).safeTransferFrom(msg.sender, address(this), _nftL1TokenId) {
      success = true;
    } catch {
      success = false;
    }
    require(success, "nft transfer failed");
    // check if the NFT has arrived
    require(IERC721(_nftL1Address).ownerOf(_nftL1TokenId) == address(this), "i");

    bytes32 nftContentHash = mintedNfts[nftKey].nftContentHash;
    uint8 nftContentType = mintedNfts[nftKey].nftContentType;
    uint16 collectionId = mintedNfts[nftKey].collectionId;
    uint40 nftIndex = mintedNfts[nftKey].nftIndex;
    uint32 creatorAccountIndex = mintedNfts[nftKey].creatorAccountIndex;
    uint16 creatorTreasuryRate = mintedNfts[nftKey].creatorTreasuryRate;

    TxTypes.DepositNft memory _tx = TxTypes.DepositNft({
      accountIndex: 0, // unknown at this point
      creatorAccountIndex: creatorAccountIndex,
      creatorTreasuryRate: creatorTreasuryRate,
      nftIndex: nftIndex,
      collectionId: collectionId,
      owner: _to,
      nftContentHash: nftContentHash,
      nftContentType: nftContentType
    });

    // compact pub data
    bytes memory pubData = TxTypes.writeDepositNftPubDataForPriorityQueue(_tx);

    // add into priority request queue
    addPriorityRequest(TxTypes.TxType.DepositNft, pubData);

    emit DepositNft(_to, nftContentHash, _nftL1Address, _nftL1TokenId, collectionId);
  }

  /// @notice Deposit or Lock BEP20 token to Layer 2 - transfer ERC20 tokens from user into contract, validate it, register deposit
  /// @param _token Token address
  /// @param _amount Token amount
  /// @param _to the receiver L1 address
  function depositBEP20(IERC20 _token, uint104 _amount, address _to) external onlyActive {
    require(_amount != 0, "I");
    // Get asset id by its address
    uint16 assetId = governance.validateAssetAddress(address(_token));
    require(!governance.pausedAssets(assetId), "b");
    // token deposits are paused

    uint256 balanceBefore = _token.balanceOf(address(this));
    _token.transferFrom(msg.sender, address(this), SafeCast.toUint128(_amount));
    // token transfer failed deposit
    uint256 balanceAfter = _token.balanceOf(address(this));
    uint128 depositAmount = SafeCast.toUint128(balanceAfter - balanceBefore);
    require(depositAmount <= MAX_DEPOSIT_AMOUNT, "C");
    require(depositAmount > 0, "D");

    registerDeposit(assetId, depositAmount, _to);
  }

  /// @notice Register full exit request - pack pubdata, add priority request
  /// @param _accountIndex Numerical id of the account
  /// @param _asset Token address, 0 address for BNB
  function requestFullExit(uint32 _accountIndex, address _asset) public onlyActive {
    require(_accountIndex <= MAX_ACCOUNT_INDEX, "e");

    uint16 assetId;
    if (_asset == address(0)) {
      assetId = 0;
    } else {
      assetId = governance.validateAssetAddress(_asset);
    }

    // Priority Queue request
    TxTypes.FullExit memory _tx = TxTypes.FullExit({
      accountIndex: _accountIndex,
      assetId: assetId,
      assetAmount: 0, // unknown at this point
      owner: msg.sender
    });
    bytes memory pubData = TxTypes.writeFullExitPubDataForPriorityQueue(_tx);
    addPriorityRequest(TxTypes.TxType.FullExit, pubData);

    // User must fill storage slot of balancesToWithdraw(msg.sender, tokenId) with nonzero value
    // In this case operator should just overwrite this slot during confirming withdrawal
    bytes22 packedBalanceKey = packAddressAndAssetId(msg.sender, assetId);
    pendingBalances[packedBalanceKey].gasReserveValue = FILLED_GAS_RESERVE_VALUE;
  }

  /// @notice Register full exit nft request - pack pubdata, add priority request
  /// @param _accountIndex Numerical id of the account
  /// @param _nftIndex account NFT index in zkbnb network
  function requestFullExitNft(uint32 _accountIndex, uint32 _nftIndex) public onlyActive {
    // Priority Queue request
    TxTypes.FullExitNft memory _tx = TxTypes.FullExitNft({
      accountIndex: _accountIndex,
      creatorAccountIndex: 0, // unknown
      creatorTreasuryRate: 0,
      nftIndex: _nftIndex,
      collectionId: 0, // unknown
      owner: msg.sender, // accountNameHahsh => owner
      creatorAddress: address(0), // unknown
      nftContentHash: bytes32(0x0), // unknown,
      nftContentType: 0 //unkown
    });
    bytes memory pubData = TxTypes.writeFullExitNftPubDataForPriorityQueue(_tx);
    addPriorityRequest(TxTypes.TxType.FullExitNft, pubData);
  }

  /// @notice Register deposit request - pack pubdata, add into onchainOpsCheck and emit OnchainDeposit event
  /// @param _assetId Asset by id
  /// @param _amount Asset amount
  /// @param _to Receiver Account's L1 address
  function registerDeposit(uint16 _assetId, uint128 _amount, address _to) internal {
    // Priority Queue request
    TxTypes.Deposit memory _tx = TxTypes.Deposit({
      accountIndex: 0, // unknown at the moment
      toAddress: _to,
      assetId: _assetId,
      amount: _amount
    });
    // compact pub data
    bytes memory pubData = TxTypes.writeDepositPubDataForPriorityQueue(_tx);
    // add into priority request queue
    addPriorityRequest(TxTypes.TxType.Deposit, pubData);
    emit Deposit(_assetId, _to, _amount);
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
      hashedPubData: hashedPubData,
      expirationBlock: expirationBlock,
      txType: _txType
    });

    emit NewPriorityRequest(msg.sender, nextPriorityRequestId, _txType, _pubData, uint256(expirationBlock));

    totalOpenPriorityRequests++;
  }
}
