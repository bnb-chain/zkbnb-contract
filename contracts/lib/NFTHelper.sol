// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

library NftHelperLibrary {
  struct AccountNft {
    address nftAddress; // nft address
    uint256 nftIndex; // nft index
  }

  struct NftHelperData {
    /// @notice L2 NFTs owned by the account in L1, maybe can store the nfts from L1 in the future
    /// @dev account address => nft address => nft index => bool
    mapping(address => mapping(address => mapping(uint256 => bool))) accountNftsMap;
    /// @dev account address => nft list
    mapping(address => AccountNft[]) accountNfts;
  }

  /**
   * @dev Add nft to a account.
   *
   * @param _account The account address at L1.
   * @param _nftAddress NFT factory address.
   * @param _nftIndex NFT index.
   */
  function addAccountNft(
    NftHelperLibrary.NftHelperData storage _data,
    address _account,
    address _nftAddress,
    uint256 _nftIndex
  ) external {
    if (!_data.accountNftsMap[_account][_nftAddress][_nftIndex]) {
      _data.accountNfts[_account].push(AccountNft({nftAddress: _nftAddress, nftIndex: _nftIndex}));
      _data.accountNftsMap[_account][_nftAddress][_nftIndex] = true;
    }
  }

  /**
   * @dev Remove nft from a account.
   *
   * @param _account The account address at L1.
   * @param _nftAddress NFT factory address.
   * @param _nftIndex NFT index.
   */
  function removeAccountNft(
    NftHelperLibrary.NftHelperData storage _data,
    address _account,
    address _nftAddress,
    uint256 _nftIndex
  ) external {
    for (uint256 i = 0; i < _data.accountNfts[_account].length; i++) {
      if (
        _data.accountNfts[_account][i].nftAddress == _nftAddress && _data.accountNfts[_account][i].nftIndex == _nftIndex
      ) {
        _data.accountNfts[_account][i] = _data.accountNfts[_account][_data.accountNfts[_account].length - 1];
        _data.accountNfts[_account].pop();
        delete _data.accountNftsMap[_account][_nftAddress][_nftIndex];
        break;
      }
    }
  }
}

/**
 * @title NFTHelper
 * @notice NFTHelper use to store and query account nfts.
 */
contract NFTHelper {
  NftHelperLibrary.NftHelperData nftHelperData;

  /**
   * @dev Query nft list by account.
   *
   * @param _account The account address at L1.
   */
  function getAccountNfts(address _account) external view returns (NftHelperLibrary.AccountNft[] memory) {
    NftHelperLibrary.AccountNft[] memory nfts = new NftHelperLibrary.AccountNft[](
      nftHelperData.accountNfts[_account].length
    );
    for (uint256 i = 0; i < nftHelperData.accountNfts[_account].length; i++) {
      NftHelperLibrary.AccountNft memory accountNft = nftHelperData.accountNfts[_account][i];
      nfts[i] = NftHelperLibrary.AccountNft({nftAddress: accountNft.nftAddress, nftIndex: accountNft.nftIndex});
    }
    return nfts;
  }

  /**
   * @dev Add nft to a account.
   *
   * @param _account The account address at L1.
   * @param _nftAddress NFT factory address.
   * @param _nftIndex NFT index.
   */
  function _addAccountNft(address _account, address _nftAddress, uint256 _nftIndex) internal {
    NftHelperLibrary.addAccountNft(nftHelperData, _account, _nftAddress, _nftIndex);
  }

  /**
   * @dev Remove nft from a account.
   *
   * @param _account The account address at L1.
   * @param _nftAddress NFT factory address.
   * @param _nftIndex NFT index.
   */
  function _removeAccountNft(address _account, address _nftAddress, uint256 _nftIndex) internal {
    NftHelperLibrary.removeAccountNft(nftHelperData, _account, _nftAddress, _nftIndex);
  }
}
