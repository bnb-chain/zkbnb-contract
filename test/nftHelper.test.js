const { expect } = require('chai');
const {ethers} = require("hardhat");
const { BigNumber } = require("ethers");

// Start test block
describe('NFTHelperTest', function () {
  const account = '0xDAFEA492D9c6733ae3d56b7Ed1ADB60692c98Bc5'
  const nftAddress = '0xe688b84b23f322a994A53dbF8E15FA82CDB71127'
  const nftIndex = 1
  beforeEach(async function () {
    const NftHelperTest = await ethers.getContractFactory('NFTHelperTest');
    this.nftHelperTest = await NftHelperTest.deploy();
  })

  it('add nfts', async function () {
    let nfts = await this.nftHelperTest.getAccountNfts(account)
    expect(nfts.length).to.equal(0)
    await this.nftHelperTest.addAccountNft(account, nftAddress, nftIndex)
    nfts = await this.nftHelperTest.getAccountNfts(account)
    expect(nfts[0].nftAddress).to.equal(nftAddress)
    expect(BigNumber.from(nfts[0].nftIndex).eq(nftIndex))
  });

  it('remove nfts', async function () {
    await this.nftHelperTest.removeAccountNft(account, nftAddress, nftIndex)
    await this.nftHelperTest.addAccountNft(account, nftAddress, nftIndex)
    nfts = await this.nftHelperTest.getAccountNfts(account)
    expect(nfts[0].nftAddress).to.equal(nftAddress)
    expect(BigNumber.from(nfts[0].nftIndex).eq(nftIndex))
    await this.nftHelperTest.removeAccountNft(account, nftAddress, nftIndex)
    nfts = await this.nftHelperTest.getAccountNfts(account)
    expect(nfts.length).to.equal(0)
  });

  it('get nfts', async function () {
    await this.nftHelperTest.addAccountNft(account, nftAddress, nftIndex)
    await this.nftHelperTest.addAccountNft(account, nftAddress, nftIndex)
    const nfts = await this.nftHelperTest.getAccountNfts(account)
    expect(nfts.length).to.equal(1)
    expect(nfts[0].nftAddress).to.equal(nftAddress)
    expect(BigNumber.from(nfts[0].nftIndex).eq(nftIndex))
  });
});
