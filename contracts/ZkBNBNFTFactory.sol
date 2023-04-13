// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/INFTFactory.sol";
import "./lib/Bytes.sol";
import "./lib/Ownable2Step.sol";

interface IZkBNB {
  function getNftTokenURI(uint8 nftContentType, bytes32 nftContentHash) external view returns (string memory tokenURI);
}

contract ZkBNBNFTFactory is ERC721, INFTFactory, Ownable2Step, ReentrancyGuard {
  address private _zkbnbAddress;

  struct NftContentURI {
    uint8 nftContentType;
    bytes32 nftContentHash;
  }

  mapping(uint256 => NftContentURI) private _uris;

  constructor(
    string memory name,
    string memory symbol,
    address zkbnbAddress,
    address owner
  ) ERC721(name, symbol) Ownable2Step(owner) {
    _zkbnbAddress = zkbnbAddress;
  }

  function mintFromZkBNB(
    address _toAddress,
    uint8 _nftContentType,
    uint256 _nftTokenId,
    bytes32 _nftContentHash
  ) external nonReentrant {
    require(_msgSender() == _zkbnbAddress, "only zkbnbAddress");
    // Minting allowed only from zkbnb
    _safeMint(_toAddress, _nftTokenId, "");
    // set tokenURI
    _uris[_nftTokenId] = NftContentURI({nftContentType: _nftContentType, nftContentHash: _nftContentHash});
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    _requireMinted(tokenId);
    NftContentURI memory uri = _uris[tokenId];
    return IZkBNB(_zkbnbAddress).getNftTokenURI(uri.nftContentType, uri.nftContentHash);
  }
}
