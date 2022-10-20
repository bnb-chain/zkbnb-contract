// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

contract NFTHelper {
    struct AccountNft {
        address nftAddress; // nft factory address
        uint256 nftIndex;  // nft index
    }

    /// @notice L2 NFTs owned by the account in L1, maybe can store the nfts from L1 in the future
    /// @dev address => NFTFactory => nft index list => bool
    mapping(address => mapping(address => mapping(uint256 => bool))) public accountNftsMap;
    mapping(address => AccountNft[]) public accountNfts;

    function _addAccountNft(address _account, address _nftAddress, uint256 _nftIndex) internal {
        if (!accountNftsMap[_account][_nftAddress][_nftIndex]) {
            accountNfts[_account].push(AccountNft({ nftAddress: _nftAddress, nftIndex: _nftIndex }));
            accountNftsMap[_account][_nftAddress][_nftIndex] = true;
        }
    }

    function _removeAccountNft(address _account, address _nftAddress, uint256 _nftIndex) internal {
        for (uint256 i = 0; i < accountNfts[_account].length; i++) {
            if (accountNfts[_account][i].nftAddress == _nftAddress
                && accountNfts[_account][i].nftIndex == _nftIndex) {
                accountNfts[_account][i] = accountNfts[_account][accountNfts[_account].length - 1];
                accountNfts[_account].pop();
                delete accountNftsMap[_account][_nftAddress][_nftIndex];
                break;
            }
        }
    }

    function getAccountNfts(address _account) external view returns (AccountNft[] memory) {
        AccountNft[] memory nfts = new AccountNft[](accountNfts[_account].length);
        for (uint256 i = 0; i < accountNfts[_account].length; i++) {
            AccountNft memory accountNft = accountNfts[_account][i];
            nfts[i] = AccountNft({ nftAddress: accountNft.nftAddress, nftIndex: accountNft.nftIndex });
        }
        return nfts;
    }
}
