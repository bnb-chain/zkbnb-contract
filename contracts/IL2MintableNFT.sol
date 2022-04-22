// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.6;


interface IL2MintableNFT
{
    /// @dev This function is called when an NFT minted on L2 is withdrawn from Zecrey.
    ///      That means the NFTs were burned on L2 and now need to be minted on L1.
    ///
    /// @param to The owner of the NFT
    /// @param tokenId The token type 'id`
    /// @param amount The amount of NFTs to mint
    /// @param minter The minter on L2, which can be used to decide if the NFT is authentic
    /// @param data Opaque data that can be used by the contract
    function mintFromL2(
        address to,
        uint256 tokenId,
        uint amount,
        address minter,
        bytes   calldata data
    )
    external;

    /// @dev Returns a list of all address that are authorized to mint NFTs on L2.
    /// @return The list of authorized minter on L2
    function minters()
    external
    view
    returns (address[] memory);
}