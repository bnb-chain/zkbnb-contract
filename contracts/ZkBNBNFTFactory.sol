// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/INFTFactory.sol";
import "./lib/Bytes.sol";
import "./lib/Ownable2Step.sol";

contract ZkBNBNFTFactory is ERC721URIStorage, INFTFactory, Ownable2Step, ReentrancyGuard {
  // tokenId => creator
  mapping(uint256 => address) private _nftCreators;

  address private _zkbnbAddress;

  constructor(
    string memory name,
    string memory symbol,
    address zkbnbAddress,
    address owner
  ) ERC721(name, symbol) Ownable2Step(owner) {
    _zkbnbAddress = zkbnbAddress;
  }

  function mintFromZkBNB(
    address _creatorAddress,
    address _toAddress,
    uint256 _nftTokenId,
    string memory _nftTokenURI,
    bytes memory _extraData
  ) external override nonReentrant {
    require(_msgSender() == _zkbnbAddress, "only zkbnbAddress");
    // Minting allowed only from zkbnb
    _safeMint(_toAddress, _nftTokenId);
    _setTokenURI(_nftTokenId, _nftTokenURI);
    _nftCreators[_nftTokenId] = _creatorAddress;
    emit MintNFTFromZkBNB(_creatorAddress, _toAddress, _nftTokenId, _extraData);
  }

  function getCreator(uint256 _tokenId) external view returns (address) {
    return _nftCreators[_tokenId];
  }

  function _beforeTokenTransfer(address, address to, uint256 tokenId) internal virtual {
    // Sending to address `0` means that the token is getting burned.
    if (to == address(0)) {
      delete _nftCreators[tokenId];
    }
  }
}
