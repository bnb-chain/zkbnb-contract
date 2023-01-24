// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

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

  /// @notice Set default factory for our contract. This factory will be used to mint an NFT token that has no factory
  /// @param _factory Address of NFT factory
  function setDefaultNFTFactory(INFTFactory _factory) external {
    governance.requireGovernor(msg.sender);
    require(address(_factory) != address(0), "mb1");
    // Factory should be non zero
    require(address(defaultNFTFactory) == address(0), "mb2");
    // NFTFactory is already set
    defaultNFTFactory = address(_factory);
    emit NewDefaultNFTFactory(address(_factory));
  }
}
