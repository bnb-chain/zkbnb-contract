import { ethers } from 'hardhat';
import { expect } from 'chai';

describe('ZkBNBRelatedERC721', function () {
  let erc721;
  let owner, acc1, acc2;

  const NAME = 'baz';
  const SYMBOL = 'BAZ';

  before(async function () {
    [owner, acc1, acc2] = await ethers.getSigners();
    const tokenId = 0;
    const ZkBNBRelatedERC721 = await ethers.getContractFactory('ZkBNBRelatedERC721');
    erc721 = await ZkBNBRelatedERC721.deploy(NAME, SYMBOL, tokenId);
    await erc721.deployed();

    expect(await erc721.ownerOf(tokenId)).to.equal(owner.address);
  });

  it('mint NFT', async function () {
    const tokenId = 1;
    await erc721.connect(acc1).mint(tokenId);
    expect(await erc721.ownerOf(tokenId)).to.equal(acc1.address);

    const _tokenId = 2;
    await erc721.connect(acc2).mint(_tokenId);
    expect(await erc721.ownerOf(_tokenId)).to.equal(acc2.address);
  });

  it('set token URI', async function () {
    const uri0 = 'ipfs://0000.json';
    await erc721.setTokenURI(0, uri0);

    expect(await erc721.tokenURI(0)).to.equal(uri0);
    await expect(erc721.connect(acc1).setTokenURI(0, 'mock_uri://1.json')).to.be.revertedWith('not owner');
  });
});
