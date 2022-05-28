// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.6;


interface NFTFactory {
    function mintFromZecrey(
        address _creatorAddress,
        address _toAddress,
        address _factoryAddress,
        uint256 _nftTokenId,
        bytes32 _nftContentHash,
        bytes memory _extraData
    )
    external;
}