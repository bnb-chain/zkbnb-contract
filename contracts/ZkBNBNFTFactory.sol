// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/INFTFactory.sol";
import "./lib/Bytes.sol";
import "./lib/Ownable2Step.sol";

contract ZkBNBNFTFactory is ERC721, INFTFactory, Ownable2Step, ReentrancyGuard {
  // Optional mapping from token ID to token content hash
  mapping(uint256 => bytes32) private _contentHashes;

  // tokenId => creator
  mapping(uint256 => address) private _nftCreators;

  string public _base;

  address private _zkbnbAddress;

  constructor(
    string memory name,
    string memory symbol,
    string memory base,
    address zkbnbAddress,
    address owner
  ) ERC721(name, symbol) Ownable2Step(owner) {
    _zkbnbAddress = zkbnbAddress;
    _base = base;
  }

  function updateBaseUri(string memory base) external onlyOwner {
    _base = base;
  }

  function mintFromZkBNB(
    address _creatorAddress,
    address _toAddress,
    uint256 _nftTokenId,
    bytes32 _nftContentHash,
    bytes memory _extraData
  ) external override nonReentrant {
    require(_msgSender() == _zkbnbAddress, "only zkbnbAddress");
    // Minting allowed only from zkbnb
    _safeMint(_toAddress, _nftTokenId);
    _contentHashes[_nftTokenId] = _nftContentHash;
    _nftCreators[_nftTokenId] = _creatorAddress;
    emit MintNFTFromZkBNB(_creatorAddress, _toAddress, _nftTokenId, _nftContentHash, _extraData);
  }

  function getContentHash(uint256 _tokenId) external view returns (bytes32) {
    return _contentHashes[_tokenId];
  }

  function getCreator(uint256 _tokenId) external view returns (address) {
    return _nftCreators[_tokenId];
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), "tokenId not exist");
    return string(abi.encodePacked(_base, Bytes.bytes32ToHexString(_contentHashes[tokenId], false)));
  }

  function _beforeTokenTransfer(address, address to, uint256 tokenId) internal virtual {
    // Sending to address `0` means that the token is getting burned.
    if (to == address(0)) {
      delete _contentHashes[tokenId];
      delete _nftCreators[tokenId];
    }
  }
}
