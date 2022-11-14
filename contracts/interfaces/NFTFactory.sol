// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.6;


interface NFTFactory {
    function mintFromZkBNB(
        address _creatorAddress,
        address _toAddress,
        uint256 _nftTokenId,
        bytes32 _nftContentHash,
        bytes memory _extraData
    )
    external;

    event MintNFTFromZkBNB(
        address indexed _creatorAddress,
        address indexed _toAddress,
        uint256 _nftTokenId,
        bytes32 _nftContentHash,
        bytes _extraData
    );
}
