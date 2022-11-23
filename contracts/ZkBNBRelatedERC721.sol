// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract ZkBNBRelatedERC721 is ERC721URIStorage {
  constructor(string memory _name, string memory _symbol, uint256 _tokenId) ERC721(_name, _symbol) {
    _mint(msg.sender, _tokenId);
  }

  function mint(uint256 _tokenId) external {
    _mint(msg.sender, _tokenId);
  }

  function setTokenURI(uint256 _tokenId, string memory _tokenURI) external {
    require(_isApprovedOrOwner(msg.sender, _tokenId), "not owner");
    _setTokenURI(_tokenId, _tokenURI);
  }
}
