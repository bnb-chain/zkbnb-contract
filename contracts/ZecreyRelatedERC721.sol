pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ZecreyRelatedERC721 is ERC721 {
    constructor(string memory _name, string memory _symbol, uint256 _tokenId) ERC721(_name, _symbol){
        _mint(msg.sender, _tokenId);
    }
}
