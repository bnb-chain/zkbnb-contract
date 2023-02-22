const { expect } = require('chai');
const { ethers } = require('hardhat');
const { BigNumber } = require('ethers');

// Start test block
describe('TestHelper', function () {
  const account1 = ethers.Wallet.createRandom().address;
  const account2 = ethers.Wallet.createRandom().address;
  const nftAddress1 = ethers.Wallet.createRandom().address;
  const nftAddress2 = ethers.Wallet.createRandom().address;
  beforeEach(async function () {
    const NftHelperLibrary = await ethers.getContractFactory('NftHelperLibrary');
    const nftHelperLibrary = await NftHelperLibrary.deploy();
    const NftHelperTest = await ethers.getContractFactory('TestHelper', {
      libraries: {
        NftHelperLibrary: nftHelperLibrary.address,
      },
    });
    this.nftHelperTest = await NftHelperTest.deploy();
  });

  it('add nfts', async function () {
    const nftsMap = new Map();
    for (let i = 1; i <= 10; i++) {
      nftsMap.set(`${nftAddress1}-${i}`, {
        nftAddress: nftAddress1,
        nftIndex: i,
      });
    }
    const nfts = nftsMap.values();
    for (const item of nfts) {
      await this.nftHelperTest.addAccountNft(account1, item.nftAddress, item.nftIndex);
      // repeat add the same nft
      await this.nftHelperTest.addAccountNft(account1, item.nftAddress, item.nftIndex);
    }

    await this.nftHelperTest.addAccountNft(account2, nftAddress1, 1);
    await this.nftHelperTest.addAccountNft(account2, nftAddress2, 2);
    const account2Nfts = await this.nftHelperTest.getAccountNfts(account2);
    expect(account2Nfts.length).to.equal(2);

    const account1Nfts = await this.nftHelperTest.getAccountNfts(account1);
    expect(account1Nfts.length).to.equal(nftsMap.size);

    account1Nfts.forEach((item) => {
      expect(nftsMap.has(`${item.nftAddress}-${item.nftIndex}`)).to.true;
    });
  });

  it('remove nfts', async function () {
    for (let i = 1; i <= 10; i++) {
      await this.nftHelperTest.addAccountNft(account1, nftAddress1, i);
    }
    const removeIndex = Math.ceil(Math.random() * 10);
    await this.nftHelperTest.removeAccountNft(account1, nftAddress1, removeIndex);

    const account1Nfts = await this.nftHelperTest.getAccountNfts(account1);
    const nftsMap = new Map();
    account1Nfts.forEach((item) => {
      nftsMap.set(`${nftAddress1}-${item.nftIndex}`, item);
    });
    for (let i = 1; i <= 10; i++) {
      if (i === removeIndex) {
        expect(nftsMap.has(`${nftAddress1}-${i}`)).to.false;
      } else {
        expect(nftsMap.has(`${nftAddress1}-${i}`)).to.true;
      }
    }
  });

  it('get nfts', async function () {
    const total = 10;
    for (let i = 1; i <= total; i++) {
      await this.nftHelperTest.addAccountNft(account1, nftAddress1, i);
    }
    const nfts = await this.nftHelperTest.getAccountNfts(account1);
    expect(nfts.length).to.equal(total);
    nfts.forEach((item, i) => {
      expect(item.nftAddress).to.equal(nftAddress1);
      expect(item.nftIndex.toString()).to.equal((i + 1).toString());
    });
  });

  it('contract exists', async function () {
    const res = await this.nftHelperTest.contractExists(account1);
    expect(res).to.equal(false);
  });
});
