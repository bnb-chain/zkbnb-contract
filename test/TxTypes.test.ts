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

  it('Withdraw pubdata should be read correctly', async function () {
    const rawPubdata =
      '05000000038b2c5a5744f42aa9269baabdd05933a96d8ef9110000000000000000000000000000000000640000fa0a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000';

    const bytes = ethers.utils.arrayify('0x' + rawPubdata);
    const pubdata = await this.bytesTest.sliceBytes(bytes, 0, 121);
    const parsed = await this.txTypesTest.testReadWithdrawPubData(pubdata);

    expect(parsed['accountIndex']).to.equal(3);
    expect(parsed['toAddress']).to.equal('0x8b2C5A5744F42AA9269BaabDd05933a96D8EF911');
    expect(parsed['assetId']).to.equal(0);
    expect(parsed['assetAmount']).to.equal(ethers.BigNumber.from('100'));
  });

  it('WithdrawNft pubdata should be read correctly', async function () {
    const rawPubdata =
      '0b00000002000000020000000000000100000000fa0ad757c6bdb5837d721b04de87c155dba72c9b076cb64d00616958131824b472cc20c3d47bb5d9926c26c21ba5c313610ad92bc967d374d7dbd3ce083e38a403b6f58a9498753a0a32000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000';

    const bytes = ethers.utils.arrayify('0x' + rawPubdata);
    const pubdata = await this.bytesTest.sliceBytes(bytes, 0, 121);
    const parsed = await this.txTypesTest.testReadWithdrawNftPubData(pubdata);

    expect(parsed['accountIndex']).to.equal(2);
    expect(parsed['creatorAccountIndex']).to.equal(2);
    expect(parsed['creatorTreasuryRate']).to.equal(0);
    expect(parsed['nftIndex']).to.equal(1);
    expect(parsed['collectionId']).to.equal(0);
    expect(parsed['toAddress']).to.equal('0xd757C6bDb5837d721B04DE87c155DBa72c9B076C');
    expect(parsed['creatorAddress']).to.equal('0xB64d00616958131824B472CC20C3d47Bb5d9926C');
    expect(parsed['nftContentHash']).to.equal('0x26c21ba5c313610ad92bc967d374d7dbd3ce083e38a403b6f58a9498753a0a32');
    expect(parsed['nftContentType']).to.equal(0);
  });

  it('Deposit pubdata should be read correctly', async function () {
    const deposit = {
      txType: 2,
      accountIndex: 1,
      toAddress: acc1.address,
      assetId: 6,
      amount: 50,
    };
    const encoded = await this.txTypesTest.testWriteDepositPubData(deposit);
    const parsed = await this.txTypesTest.testReadDepositPubData(encoded);

    expect(parsed['toAddress']).to.equal(acc1.address);
    expect(parsed['assetId']).to.equal(deposit.assetId);
    expect(parsed['amount']).to.equal(deposit.amount);
  });

  it('DepositNft pubdata should be read correctly', async function () {
    const depositNft = {
      txType: 3,
      accountIndex: 4,
      creatorAccountIndex: 5,
      creatorTreasuryRate: 20,
      nftIndex: 111,
      collectionId: 222,
      owner: owner.address,
      nftContentHash: ethers.utils.randomBytes(32),
      nftContentType: 1,
    };

    const encoded = await this.txTypesTest.testWriteDepositNftPubData(depositNft);
    const parsed = await this.txTypesTest.testReadDepositNftPubData(encoded);

    expect(parsed['creatorAccountIndex']).to.equal(depositNft.creatorAccountIndex);
    expect(parsed['creatorTreasuryRate']).to.equal(depositNft.creatorTreasuryRate);
    expect(parsed['nftIndex']).to.equal(depositNft.nftIndex);
    expect(parsed['collectionId']).to.equal(depositNft.collectionId);
    expect(parsed['owner']).to.equal(depositNft.owner);
    expect(parsed['nftContentHash']).to.equal(ethers.utils.hexlify(depositNft.nftContentHash));
    expect(parsed['nftContentType']).to.equal(depositNft.nftContentType);
  });
});
