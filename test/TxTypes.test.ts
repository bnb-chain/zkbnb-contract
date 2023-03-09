import chai, { expect } from 'chai';
import { ethers } from 'hardhat';
import { FakeContract, smock } from '@defi-wonderland/smock';

describe('TxTypesTest', function () {
  let owner, acc1;

  beforeEach(async function () {
    [owner, acc1] = await ethers.getSigners();

    const TxTypesTest = await ethers.getContractFactory('TxTypesTest');
    this.txTypesTest = await TxTypesTest.deploy();
  });

  it('FullExit pubdata should be serialized and deserialized correctly', async function () {
    const fullExit = {
      txType: 12,
      accountIndex: 1,
      assetId: 0,
      assetAmount: 100,
      owner: owner.address,
    };
    const encoded = await this.txTypesTest.testWriteFullExitPubData(fullExit);
    const parsed = await this.txTypesTest.testReadFullExitPubData(encoded);

    expect(parsed['accountIndex']).to.equal(fullExit.accountIndex);
    expect(parsed['assetId']).to.equal(fullExit.assetId);
    expect(parsed['owner']).to.equal(fullExit.owner);
  });

  it('FullExitNft pubdata should be serialized and deserialized correctly', async function () {
    const fullExitNft = {
      txType: 13,
      accountIndex: 1,
      creatorAccountIndex: 2,
      creatorTreasuryRate: 0,
      nftIndex: 0,
      collectionId: 1,
      owner: owner.address,
      creatorAddress: acc1.address, // creatorAddress
      nftContentHash: ethers.constants.HashZero,
      nftContentType: 0, // New added
    };

    const encoded = await this.txTypesTest.testWriteFullExitNftPubData(fullExitNft);
    const parsed = await this.txTypesTest.testReadFullExitNftPubData(encoded);

    expect(parsed['accountIndex']).to.equal(fullExitNft.accountIndex);
    expect(parsed['nftIndex']).to.equal(fullExitNft.nftIndex);
    expect(parsed['owner']).to.equal(fullExitNft.owner);
    expect(parsed['creatorAddress']).to.equal(fullExitNft.creatorAddress);
  });
});
