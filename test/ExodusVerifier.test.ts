import { assert, chai } from 'chai';
import { ethers } from 'hardhat';
import { SMT, buildPoseidon, newMemEmptyTrie, poseidonContract } from 'circomlibjs';
import { Scalar } from 'ffjavascript';
import { getAccountNameHash, randomBN } from './util';
import exitDataJson from './performDesertAsset.json';

describe('ExodusVerifier', function () {
  let owner, addr1;
  // poseidon wasm
  let poseidon;

  // poseidon contract with inputs uint256[2]
  let poseidonT3;
  // poseidon contract with inputs uint256[5]
  let poseidonT6;
  // poseidon contract with inputs uint256[6]
  let poseidonT7;
  // contract to verify exodus proof
  let exodusVerifier;

  let assetRoot;
  let accountRoot;

  before(async function () {
    [owner, addr1] = await ethers.getSigners();

    poseidon = await buildPoseidon();

    const PoseidonT3 = new ethers.ContractFactory(
      poseidonContract.generateABI(2),
      poseidonContract.createCode(2),
      owner,
    );
    poseidonT3 = await PoseidonT3.deploy();
    await poseidonT3.deployed();

    const PoseidonT6 = new ethers.ContractFactory(
      poseidonContract.generateABI(5),
      poseidonContract.createCode(5),
      owner,
    );
    poseidonT6 = await PoseidonT6.deploy();
    await poseidonT6.deployed();

    const PoseidonT7 = new ethers.ContractFactory(
      poseidonContract.generateABI(6),
      poseidonContract.createCode(6),
      owner,
    );
    poseidonT7 = await PoseidonT7.deploy();
    await poseidonT7.deployed();

    const ExodusVerifier = await ethers.getContractFactory('ExodusVerifierTest');
    exodusVerifier = await ExodusVerifier.deploy(poseidonT3.address, poseidonT6.address, poseidonT7.address);
    await exodusVerifier.deployed();
  });

  it('should hash asset leaf node correctly', async () => {
    const inputs = [exitDataJson.ExitData.Amount, exitDataJson.ExitData.OfferCanceledOrFinalized];
    const actual = await poseidonT3['poseidon(uint256[2])'](inputs);
    const expect = poseidon(inputs);

    assert.equal(actual.toString(), poseidon.F.toString(expect));
  });

  it('should calculate asset tree root node correctly', async () => {
    assetRoot = await exodusVerifier.testGetAssetRoot(
      exitDataJson.ExitData.AssetId,
      exitDataJson.ExitData.Amount,
      exitDataJson.ExitData.OfferCanceledOrFinalized,
      exitDataJson.AssetMerkleProof.map((el: string) => ethers.BigNumber.from(el)),
    );

    console.log('done calculate asset root:', assetRoot);
  });

  it('should hash account leaf node correctly', async () => {
    const inputs = [
      ethers.BigNumber.from(exitDataJson.ExitData.AccountNameHash),
      ethers.BigNumber.from(exitDataJson.ExitData.PubKeyX),
      ethers.BigNumber.from(exitDataJson.ExitData.PubKeyY),
      exitDataJson.ExitData.Nonce,
      exitDataJson.ExitData.CollectionNonce,
      assetRoot,
    ];
    const actual = await poseidonT7['poseidon(uint256[6])'](inputs);
    const expect = poseidon(inputs);
    assert.equal(actual.toString(), poseidon.F.toString(expect));
  });

  it('should calculate account root correctly', async () => {
    accountRoot = await exodusVerifier.testGetAccountRoot(
      exitDataJson.ExitData.AccountId,
      ethers.BigNumber.from(exitDataJson.ExitData.AccountNameHash),
      ethers.BigNumber.from(exitDataJson.ExitData.PubKeyX),
      ethers.BigNumber.from(exitDataJson.ExitData.PubKeyY),
      ethers.BigNumber.from(exitDataJson.ExitData.Nonce),
      exitDataJson.ExitData.CollectionNonce,
      assetRoot,
      exitDataJson.AccountMerkleProof.map((el: string) => ethers.BigNumber.from(el)),
    );
    console.log('done calculate account root:', accountRoot);
  });

  it.skip('exodus proof verification should pass', async () => {
    const _stateRoot = poseidon([accountSMT.root, nftSMT.root]);
    const stateRoot = ethers.BigNumber.from(_stateRoot);

    console.log('stateRoot: ', stateRoot);
    const assetProof = await accountAssetSMT.find(exitData.assetId);
    const accountProof = await accountSMT.find(exitData.accountId);
    const nftProof = await nftSMT.find(exitData.nftIndex);

    console.log(assetProof.siblings);
    console.log(accountProof.siblings);
    console.log(nftProof.siblings);

    const assetMerkleProof = toProofParam(assetProof.siblings, 15);
    const accountMerkleProof = toProofParam(accountProof, 31);
    const nftMerkleProof = toProofParam(nftProof, 39);

    const res = await exodusVerifier.verifyExitProof(
      stateRoot,
      [0, 2, 0, 100, 1, randomBN(), randomBN(), randomBN(), 1, 1, 1, 2, randomBN(), 5, 1],
      assetMerkleProof,
      accountMerkleProof,
      nftMerkleProof,
    );

    // assert(res);
    console.log('done verifyExitProof: ', res);
  });
});
