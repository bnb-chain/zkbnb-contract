import { assert } from 'chai';
import { ethers } from 'hardhat';
import * as poseidonContract from './poseidon_gencontract';
import { BigNumber } from 'ethers';

import exitDataJson from './performDesertAsset5.json';
import exitNftJson from './performDesertNft3.json';

import buildPoseidon from './poseidon_reference';

describe('DesertVerifier', function () {
  let owner;
  // poseidon wasm
  let poseidon;

  // poseidon contract with inputs uint256[2]
  let poseidonT3;
  // poseidon contract with inputs uint256[6]
  let poseidonT7;
  // contract to verify exit proof
  let desertVerifier;

  before(async function () {
    [owner] = await ethers.getSigners();

    poseidon = await buildPoseidon();

    const PoseidonT3 = new ethers.ContractFactory(
      poseidonContract.generateABI(2),
      poseidonContract.createCode(2),
      owner,
    );
    poseidonT3 = await PoseidonT3.deploy();
    await poseidonT3.deployed();

    const PoseidonT7 = new ethers.ContractFactory(
      poseidonContract.generateABI(6),
      poseidonContract.createCode(6),
      owner,
    );
    poseidonT7 = await PoseidonT7.deploy();
    await poseidonT7.deployed();

    const DesertVerifier = await ethers.getContractFactory('DesertVerifierTest');
    desertVerifier = await DesertVerifier.deploy(poseidonT3.address, poseidonT7.address);
    await desertVerifier.deployed();
  });

  describe('desert asset', function () {
    let assetRoot;
    let accountRoot;
    let stateHash;

    it('should hash asset leaf node correctly', async () => {
      const inputs = [
        exitDataJson.AssetExitData.Amount.toString(),
        exitDataJson.AssetExitData.OfferCanceledOrFinalized.toString(),
      ];
      const actual = await poseidonT3['poseidon(uint256[2])'](inputs);
      const reference = poseidon(inputs);
      const expect = '218de925460d1e5cf0a26c27124e23a380ec0e2d30518b5d108005bc02c5879e'; // taken from L2's log

      assert.equal(actual.toString(), poseidon.F.toString(reference));
      assert.equal(actual.toHexString(), '0x' + expect);
    });

    it('check asset tree root node', async () => {
      assetRoot = await desertVerifier.testGetAssetRoot(
        exitDataJson.AssetExitData.AssetId,
        BigNumber.from(exitDataJson.AssetExitData.Amount.toString()),
        exitDataJson.AssetExitData.OfferCanceledOrFinalized,
        exitDataJson.AssetMerkleProof.map((el: string) => BigNumber.from('0x' + el)),
      );

      const expectAssetRoot = '11d6f9a8ef166dd57b9809e47c679658b8eb3c5d237f912acce178342ce07d49'; // taken from L2's log

      assert.equal(assetRoot.toHexString(), '0x' + expectAssetRoot);
    });

    it('check account leaf hash', async () => {
      const inputs = [
        exitDataJson.AccountExitData.L1Address,
        // BigNumber.from(exitDataJson.AccountExitData.L1Address),
        ethers.utils.arrayify('0x' + exitDataJson.AccountExitData.PubKeyX),
        ethers.utils.arrayify('0x' + exitDataJson.AccountExitData.PubKeyY),
        exitDataJson.AccountExitData.Nonce,
        exitDataJson.AccountExitData.CollectionNonce,
        assetRoot,
      ];

      const actual = await poseidonT7['poseidon(uint256[6])'](inputs);
      const expect = poseidon(inputs);
      assert.equal(actual.toString(), poseidon.F.toString(expect));

      const expectLog = '0x8d177d83a2bcfc59091b802531712ae222bb78b586ac1a5099b02d92104b84';
      assert.equal(actual.toHexString(), expectLog);
    });

    it('check account root', async () => {
      accountRoot = await desertVerifier.testGetAccountRoot(
        exitDataJson.AccountExitData.AccountId,
        exitDataJson.AccountExitData.L1Address,
        ethers.utils.arrayify('0x' + exitDataJson.AccountExitData.PubKeyX),
        ethers.utils.arrayify('0x' + exitDataJson.AccountExitData.PubKeyY),
        exitDataJson.AccountExitData.Nonce,
        exitDataJson.AccountExitData.CollectionNonce,
        assetRoot,
        exitDataJson.AccountMerkleProof.map((el: string) => BigNumber.from('0x' + el)),
      );

      const expectAccountRoot = '2a754f8b0b683bd08de6425b8b36be15a7f29d32bb4ee37873e43a5721b3d32c';
      assert.equal(accountRoot.toHexString(), '0x' + expectAccountRoot);
    });

    it('check state hash', async () => {
      const inputs = [accountRoot, '0x' + exitDataJson.NftRoot];
      const _stateHash = await poseidonT3['poseidon(uint256[2])'](inputs);
      const expectStateHash = '24f44b2a9149d4c5618369b5b4f4214f081330907c0f7deaa4d68f8e670bbe75';

      assert.equal(_stateHash.toHexString(), '0x' + expectStateHash);
      stateHash = _stateHash;
    });

    it('desert proof verification should pass', async () => {
      const res = await desertVerifier.verifyExitProofBalance(
        stateHash,
        '0x' + exitDataJson.NftRoot,
        [
          exitDataJson.AssetExitData.AssetId,
          BigNumber.from(exitDataJson.AssetExitData.Amount.toString()),
          exitDataJson.AssetExitData.OfferCanceledOrFinalized,
        ],
        [
          exitDataJson.AccountExitData.AccountId,
          exitDataJson.AccountExitData.L1Address,
          ethers.utils.hexZeroPad(BigNumber.from(exitDataJson.AccountExitData.PubKeyX).toHexString(), 32),
          ethers.utils.hexZeroPad(BigNumber.from(exitDataJson.AccountExitData.PubKeyY).toHexString(), 32),
          exitDataJson.AccountExitData.Nonce,
          exitDataJson.AccountExitData.CollectionNonce,
        ],
        exitDataJson.AssetMerkleProof.map((el: string) => BigNumber.from('0x' + el)),
        exitDataJson.AccountMerkleProof.map((el: string) => BigNumber.from('0x' + el)),
      );

      assert(res);
    });
  });

  describe('desert nfts', function () {
    let nftRoot: BigNumber;
    let stateRoot: BigNumber;

    it('check nft leaf node', async () => {
      for (const nft of exitNftJson.ExitNfts) {
        const inputs = [
          nft.CreatorAccountIndex,
          nft.OwnerAccountIndex,
          BigNumber.from('0x' + nft.NftContentHash1),
          BigNumber.from('0x' + nft.NftContentHash2),
          nft.CreatorTreasuryRate,
          nft.CollectionId,
        ];
        const actual = await poseidonT7['poseidon(uint256[6])'](inputs);
        const expect = poseidon(inputs);

        assert.equal(actual.toString(), poseidon.F.toString(expect));
      }
    });

    it('check nft root', async () => {
      const accountRoot = await desertVerifier.testGetAccountRoot(
        exitNftJson.AccountExitData.AccountId,
        exitNftJson.AccountExitData.L1Address,
        ethers.utils.arrayify('0x' + exitNftJson.AccountExitData.PubKeyX),
        ethers.utils.arrayify('0x' + exitNftJson.AccountExitData.PubKeyY),
        exitNftJson.AccountExitData.Nonce,
        exitNftJson.AccountExitData.CollectionNonce,
        '0x' + exitNftJson.AssetRoot,
        exitNftJson.AccountMerkleProof.map((el: string) => BigNumber.from('0x' + el)),
      );
      assert.equal(
        accountRoot.toString(),
        '12595822472651301667075947699693502617967676867936922398730089118953186130170',
      );

      for (const [i, nft] of exitNftJson.ExitNfts.entries()) {
        const nftMerkleProof = exitNftJson.NftMerkleProofs[i];

        nftRoot = await desertVerifier.testGetNftRoot(
          nft.NftIndex,
          nft.NftContentType,
          nft.OwnerAccountIndex,
          nft.CreatorAccountIndex,
          ethers.utils.arrayify('0x' + nft.NftContentHash1),
          ethers.utils.arrayify('0x' + nft.NftContentHash2),
          nft.CreatorTreasuryRate,
          nft.CollectionId,
          nftMerkleProof.map((el: string) => BigNumber.from('0x' + el)),
        );

        assert.equal(
          nftRoot.toString(),
          '5257726459013007500408506418284221508847824135721624095602603351497287749960',
        );

        stateRoot = await poseidonT3['poseidon(uint256[2])']([accountRoot, nftRoot]);

        assert.equal(
          stateRoot.toString(),
          '10591573734374619365752166390356942902402176266422195095146487009777481713142',
        );
      }
    });

    it('desert nft proof verification should pass', async () => {
      const nftProof = new Array<BigNumber>(40).fill(BigNumber.from(0));
      const nftProofs = [nftProof];

      for (const [i, proof] of exitNftJson.NftMerkleProofs.entries()) {
        nftProofs[i] = proof.map((el: string) => BigNumber.from('0x' + el));
      }
      // There is only 1 NFT in the JSON
      const nftData = exitNftJson.ExitNfts[0];

      const res = await desertVerifier.verifyExitNftProof(
        stateRoot,
        '0x' + exitNftJson.AssetRoot,
        [
          exitNftJson.AccountExitData.AccountId,
          exitNftJson.AccountExitData.L1Address,
          ethers.utils.arrayify('0x' + exitNftJson.AccountExitData.PubKeyX),
          ethers.utils.arrayify('0x' + exitNftJson.AccountExitData.PubKeyY),
          exitNftJson.AccountExitData.Nonce,
          exitNftJson.AccountExitData.CollectionNonce,
        ],
        [
          [
            nftData.NftIndex,
            nftData.OwnerAccountIndex,
            nftData.CreatorAccountIndex,
            nftData.CreatorTreasuryRate,
            nftData.CollectionId,
            ethers.utils.arrayify('0x' + nftData.NftContentHash1),
            ethers.utils.arrayify('0x' + nftData.NftContentHash2),
            nftData.NftContentType,
          ],
        ],
        nftProofs,
        exitNftJson.AccountMerkleProof.map((el: string) => BigNumber.from('0x' + el)),
      );

      assert(res);
    });
  });
});
