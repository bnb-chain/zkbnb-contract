import { assert, chai } from 'chai';
import { ethers } from 'hardhat';
import { SMT, buildPoseidon, newMemEmptyTrie, poseidonContract } from 'circomlibjs';
import { Scalar } from 'ffjavascript';
import { getAccountNameHash, randomBN } from './util';

// siblings[0] is the highest proof
// res[0] is the lowest proof
function toProofParam(siblings, length) {
    let res = new Array(length).fill(ethers.constants.Zero);
    let index = length - 1;
    for (let i = 0; i < siblings.length; i++) {
        const n = ethers.BigNumber.from(siblings[i]);
        res[index] = n;
        index -= 1;
    }
    return res;
}

async function initSMT() {
    const smt = await newMemEmptyTrie();
    await smt.insert(12, 11);
    await smt.insert(23, 22);
    await smt.insert(34, 33);
    await smt.insert(45, 44);
    console.log(smt.root.toString());
    return smt;
    //    const proof = await smt.find(0);
    //   console.log('proofs', proof.siblings.toString());
}

describe('ExodusVerifier', function() {
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

    // let mimc;

    let accountSMT;
    let accountAssetSMT;
    let nftSMT;

    // const nameHash = getAccountNameHash('foo');
    const exitData = {
        assetId: 0,
        accountId: 2,
        nftIndex: 0,
        amount: 100,
        offercanceledorfinalized: 1,
        nameHash: randomBN(),
        pubX: randomBN(),
        pubY: randomBN(),
        nonce: 1,
        collectionNonce: 1,
        creatorAccountIndex: 1,
        ownerAccountIndex: 2,
        nftContentHash: randomBN(),
        creatorTreasuryRate: 5,
        collectionId: 1,
    };

    before(async function() {
        [owner, addr1] = await ethers.getSigners();

        accountSMT = await initSMT();
        accountAssetSMT = await initSMT();
        nftSMT = await initSMT();

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

        // mimcJS = await buildMimc7();
        // const C = new ethers.ContractFactory(
        //     mimc7Contract.abi,
        //     mimc7Contract.createCode('SEED', 91),
        //     owner
        // );

        // mimc = await C.deploy();

        const ExodusVerifier = await ethers.getContractFactory('ExodusVerifierTest');
        exodusVerifier = await ExodusVerifier.deploy(poseidonT3.address, poseidonT6.address, poseidonT7.address);
        await exodusVerifier.deployed();
    });

    it('should hash asset leaf node correctly', async () => {
        const inputs = [exitData.amount, exitData.offerCanceledOrFinalized];
        const actual = await poseidonT3['poseidon(uint256[2])'](inputs);
        const expect = poseidon(inputs);

        assert.equal(actual.toString(), poseidon.F.toString(expect));

        await accountAssetSMT.insert(exitData.assetId, actual);
    });

    it('should hash account leaf node correctly', async () => {
        const assetRoot = ethers.BigNumber.from(accountAssetSMT.root);
        console.log('asset root: ', accountAssetSMT.root.toString());

        const inputs = [
            exitData.nameHash,
            exitData.pubX,
            exitData.pubY,
            exitData.nonce,
            exitData.collectionNonce,
            assetRoot,
        ];
        const actual = await poseidonT7['poseidon(uint256[6])'](inputs);
        const expect = poseidon(inputs);
        assert.equal(actual.toString(), poseidon.F.toString(expect));

        await accountSMT.insert(exitData.accountId, actual);
    });

    it('should hash nft leaf node correctly', async () => {
        const inputs = [
            exitData.creatorAccountIndex,
            exitData.ownerAccountIndex,
            exitData.nftContentHash,
            exitData.creatorTreasuryRate,
            exitData.collectionId,
        ];
        const actual = await poseidonT6['poseidon(uint256[5])'](inputs);
        const expect = poseidon(inputs);
        assert.equal(actual.toString(), poseidon.F.toString(expect));

        await nftSMT.insert(exitData.nftIndex, actual);
    });

    it('should asset tree root node correctly', async () => {
        const assetId = 0;
        const amount = 1;
        const offerCanceledOrFinalized = 1;
        const assetProof = await accountAssetSMT.find(exitData.assetId);

        const assetMerkleProof = toProofParam(assetProof.siblings, 15);
        const assetRoot = await exodusVerifier.testGetAssetRoot(assetId, amount, offerCanceledOrFinalized, assetMerkleProof);

        console.log('done calculate asset root:', assetRoot);
    });

    it('exodus proof verification should pass', async () => {
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

        const res = await exodusVerifier.verifyExitProof(stateRoot, [0, 2, 0, 100, 1, randomBN(), randomBN(), randomBN(), 1, 1, 1, 2, randomBN(), 5, 1], assetMerkleProof, accountMerkleProof, nftMerkleProof);

        // assert(res);
        console.log('done verifyExitProof: ', res);
    });
});
