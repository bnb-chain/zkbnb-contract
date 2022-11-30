// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../lib/NFTHelper.sol";

contract NFTHelperTest is NFTHelper {
  constructor() {}

  function addAccountNft(address _account, address _nftAddress, uint256 _nftIndex) external {
    _addAccountNft(_account, _nftAddress, _nftIndex);
  }

  function removeAccountNft(address _account, address _nftAddress, uint256 _nftIndex) external {
    _removeAccountNft(_account, _nftAddress, _nftIndex);
  }
}
