import chai, { expect } from 'chai';
import { ethers } from 'hardhat';
import { FakeContract, smock } from '@defi-wonderland/smock';

describe('TxTypesTest', function () {
  let owner, acc1;

  beforeEach(async function () {
    [owner, acc1] = await ethers.getSigners();

    const TxTypesTest = await ethers.getContractFactory('TxTypesTest');
    this.txTypesTest = await TxTypesTest.deploy();
    const BytesTest = await ethers.getContractFactory('BytesTest');
    this.bytesTest = await BytesTest.deploy();
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
  });

  it('ChangePubKey pudata should be deserialized correctly', async function () {
    const rawPubdata =
      '0100000002106fee935e03ee211956f7734309c263569ddb921b0dae1f281959ace7d975ce29ffdf94bc8f84a7838e83efc7c83571e286aa8c355922938da153bff11f5ed7b64d00616958131824b472cc20c3d47bb5d9926c0000000000007d0a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000002b64d00616958131824b472cc20c3d47bb5d9926c000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000';

    const bytes = ethers.utils.arrayify('0x' + rawPubdata);
    const pubdata = await this.bytesTest.sliceBytes(bytes, 0, 121);
    const parsed = await this.txTypesTest.testReadChangePubKeyPubData(pubdata);

    expect(parsed['accountIndex']).to.equal(2);
    expect(parsed['pubkeyX']).to.equal('0x106fee935e03ee211956f7734309c263569ddb921b0dae1f281959ace7d975ce');
    expect(parsed['pubkeyY']).to.equal('0x29ffdf94bc8f84a7838e83efc7c83571e286aa8c355922938da153bff11f5ed7');
    expect(parsed['owner']).to.equal('0xB64d00616958131824B472CC20C3d47Bb5d9926C');
    expect(parsed['nonce']).to.equal(0);
  });
});
