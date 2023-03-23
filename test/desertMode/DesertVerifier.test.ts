import { assert, chai } from 'chai';
import { ethers } from 'hardhat';
import { SMT, buildPoseidon, newMemEmptyTrie, poseidonContract } from 'circomlibjs';
import { Scalar } from 'ffjavascript';
import { randomBN } from '../util';
import exitDataJson from './performDesertAsset.json';
import exitNftJson from './performDesertNft.json';

describe('DesertVerifier', function () {
  let owner, addr1;
  // poseidon wasm
  let poseidon;

  // poseidon contract with inputs uint256[2]
  let poseidonT3;
  // poseidon contract with inputs uint256[5]
  let poseidonT6;
  // poseidon contract with inputs uint256[6]
  let poseidonT7;
  // contract to verify exit proof
  let desertVerifier;

  let assetRoot;
  let accountRoot;
  let nftRoot;

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

    const DesertVerifier = await ethers.getContractFactory('DesertVerifierTest');
    desertVerifier = await DesertVerifier.deploy(poseidonT3.address, poseidonT6.address, poseidonT7.address);
    await desertVerifier.deployed();
  });

  it('should hash asset leaf node correctly', async () => {
    const inputs = [exitDataJson.AssetExitData.Amount, exitDataJson.AssetExitData.OfferCanceledOrFinalized];
    const actual = await poseidonT3['poseidon(uint256[2])'](inputs);
    const expect = poseidon(inputs);

    assert.equal(actual.toString(), poseidon.F.toString(expect));
  });

  it('check asset tree root node', async () => {
    assetRoot = await desertVerifier.testGetAssetRoot(
      exitDataJson.AssetExitData.AssetId,
      exitDataJson.AssetExitData.Amount,
      exitDataJson.AssetExitData.OfferCanceledOrFinalized,
      exitDataJson.AssetMerkleProof.map((el: string) => ethers.BigNumber.from('0x' + el)),
    );

    console.log('done calculate asset root:', assetRoot.toHexString());
  });

  it('check account leaf node', async () => {
    const inputs = [
      ethers.BigNumber.from(exitDataJson.AccountExitData.L1Address),
      ethers.BigNumber.from('0x' + exitDataJson.AccountExitData.PubKeyX),
      ethers.BigNumber.from('0x' + exitDataJson.AccountExitData.PubKeyY),
      exitDataJson.AccountExitData.Nonce,
      exitDataJson.AccountExitData.CollectionNonce,
      assetRoot,
    ];
    const actual = await poseidonT7['poseidon(uint256[6])'](inputs);
    const expect = poseidon(inputs);
    assert.equal(actual.toString(), poseidon.F.toString(expect));
  });

  it('check account root', async () => {
    accountRoot = await desertVerifier.testGetAccountRoot(
      exitDataJson.AccountExitData.AccountId,
      ethers.BigNumber.from(exitDataJson.AccountExitData.L1Address),
      ethers.BigNumber.from('0x' + exitDataJson.AccountExitData.PubKeyX),
      ethers.BigNumber.from('0x' + exitDataJson.AccountExitData.PubKeyY),
      exitDataJson.AccountExitData.Nonce,
      exitDataJson.AccountExitData.CollectionNonce,
      assetRoot,
      exitDataJson.AccountMerkleProof.map((el: string) => ethers.BigNumber.from('0x' + el)),
    );
    console.log('done calculate account root:', accountRoot.toHexString());
  });

  it('check nft leaf node', async () => {
    for (const nft of exitNftJson.ExitNfts) {
      const inputs = [
        nft.CreatorAccountIndex,
        nft.OwnerAccountIndex,
        ethers.BigNumber.from('0x' + nft.NftContentHash),
        nft.CreatorTreasuryRate,
        nft.NftContentType,
      ];
      const actual = await poseidonT6['poseidon(uint256[5])'](inputs);
      const expect = poseidon(inputs);
      assert.equal(actual.toString(), poseidon.F.toString(expect));
    }
  });

  it('check nft root', async () => {
    for (const [i, nft] of exitNftJson.ExitNfts.entries()) {
      const nftMerkleProof = exitNftJson.NftMerkleProofs[i];

      nftRoot = await desertVerifier.testGetNftRoot(
        nft.NftIndex,
        nft.CreatorAccountIndex,
        nft.OwnerAccountIndex,
        ethers.BigNumber.from('0x' + nft.NftContentHash),
        nft.CreatorTreasuryRate,
        nft.CollectionId,
        nft.NftContentType,
        nftMerkleProof.map((el: string) => ethers.BigNumber.from('0x' + el)),
      );

      console.log('done. nft root is: ', nftRoot.toHexString());
    }
  });

  it.skip('desert proof verification should pass', async () => {
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

    const res = await desertVerifier.verifyExitProof(
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
