import { ethers } from 'hardhat';
import chai, { expect } from 'chai';
import { smock } from '@defi-wonderland/smock';
import assert from 'assert';
import CID = require('cids');

chai.use(smock.matchers);
const abi = ethers.utils.defaultAbiCoder;

describe('NFT functionality', function () {
  let governance;
  let mockZkBNBVerifier;
  let mockNftFactory;

  let zkBNB; // ZkBNBTest.sol
  let additionalZkBNB; // AdditionalZkBNB.sol
  let zkBNBNFTFactory;

  let owner, acc1, acc2;

  let utils;

  const mockHash = ethers.utils.hexZeroPad(
    '0x3579B1273F940172FEBE72B0BFB51C15F49F23E558CA7F03DFBA2D97D8287A30'.toLowerCase(),
    32,
  );

  // The prefix to the CID before the content hash. Refer to https://docs.ipfs.tech/concepts/content-addressing/#cid-conversion for more details.
  const baseURI = `ipfs://f01701220`;

  before(async function () {
    [owner, acc1, acc2] = await ethers.getSigners();
    const Governance = await ethers.getContractFactory('Governance');
    governance = await Governance.deploy();
    await governance.deployed();

    const MockZkBNBVerifier = await smock.mock('ZkBNBVerifier');
    mockZkBNBVerifier = await MockZkBNBVerifier.deploy();
    await mockZkBNBVerifier.deployed();

    const Utils = await ethers.getContractFactory('Utils');
    utils = await Utils.deploy();
    await utils.deployed();

    const AdditionalZkBNB = await ethers.getContractFactory('AdditionalZkBNB');
    additionalZkBNB = await AdditionalZkBNB.deploy();
    await additionalZkBNB.deployed();

    const ZkBNBTest = await ethers.getContractFactory('ZkBNBTest', {
      libraries: {
        Utils: utils.address,
      },
    });
    zkBNB = await ZkBNBTest.deploy();
    await zkBNB.deployed();

    const initParams = ethers.utils.defaultAbiCoder.encode(
      ['address', 'address', 'address', 'bytes32'],
      [
        governance.address,
        mockZkBNBVerifier.address,
        additionalZkBNB.address,
        ethers.utils.formatBytes32String('genesisStateRoot'),
      ],
    );
    await zkBNB.initialize(initParams);

    const ZkBNBNFTFactory = await ethers.getContractFactory('ZkBNBNFTFactory');
    zkBNBNFTFactory = await ZkBNBNFTFactory.deploy('ZkBNBNft', 'Zk', zkBNB.address, owner.address);
    await zkBNBNFTFactory.deployed();
    assert.equal(await zkBNBNFTFactory.name(), 'ZkBNBNft');
    assert.equal(await zkBNBNFTFactory.symbol(), 'Zk');

    const MockNftFactory = await smock.mock('ZkBNBNFTFactory');
    mockNftFactory = await MockNftFactory.deploy('FooNft', 'FOO', zkBNB.address, owner.address);
    await mockNftFactory.deployed();

    const abi = ethers.utils.defaultAbiCoder;
    const byteAddr = abi.encode(['address'], [owner.address]);
    await governance.initialize(byteAddr);
    await governance.setZkBNBAddress(zkBNB.address);
    await governance.updateBaseURI(0, baseURI);

    await expect(await governance.setDefaultNFTFactory(mockNftFactory.address))
      .to.emit(governance, 'SetDefaultNFTFactory')
      .withArgs(mockNftFactory.address);
  });

  it('check default NFT Factory', async function () {
    expect(await governance.defaultNFTFactory()).to.equal(mockNftFactory.address);
  });

  it('on ERC721 received', async function () {
    const HashZero = ethers.constants.HashZero;

    await zkBNB.onERC721Received(owner.address, acc1.address, 0, HashZero);
  });

  describe('withdraw NFT from L2 to L1 and store as IPFS CID hash', function () {
    const mockNftIndex = 0;
    let withdrawOp;

    before('Init onERC721Received and withdraw op', async function () {
      const HashZero = ethers.constants.HashZero;

      await zkBNB.onERC721Received(owner.address, acc1.address, 0, HashZero);
    });

    it('NFT is not minted before withdrawal', async function () {
      const nftKey = ethers.utils.keccak256(abi.encode(['address', 'uint256'], [mockNftFactory.address, mockNftIndex]));
      const _l2Nft = await zkBNB.getMintedL2NftInfo(nftKey);

      expect(_l2Nft['nftContentHash']).to.equal(ethers.utils.hexZeroPad(ethers.utils.hexlify(0), 32));
    });

    it('should perform mint and then withdraw', async function () {
      withdrawOp = {
        accountIndex: 1,
        creatorAccountIndex: 0,
        creatorTreasuryRate: 5,
        nftIndex: mockNftIndex,
        collectionId: 0,
        gasFeeAccountIndex: 1,
        toAddress: acc1.address,
        creatorAddress: owner.address,
        nftContentHash: mockHash,
        nftContentType: 0,
      };

      await expect(await zkBNB.testWithdrawOrStoreNFT(withdrawOp))
        .to.emit(zkBNB, 'WithdrawNft')
        .withArgs(1, mockNftFactory.address, acc1.address, mockNftIndex);

      const nftKey = ethers.utils.keccak256(abi.encode(['address', 'uint256'], [mockNftFactory.address, mockNftIndex]));
      const l2Nft = await zkBNB.getMintedL2NftInfo(nftKey);

      expect(l2Nft['nftIndex']).to.equal(mockNftIndex);
      expect(l2Nft['creatorAccountIndex']).to.equal(0);
      expect(l2Nft['creatorTreasuryRate']).to.equal(5);
      expect(l2Nft['nftContentHash']).to.equal(mockHash);
      expect(l2Nft['collectionId']).to.equal(0);
    });

    it('L1 NFT should be owned by acc1', async function () {
      //First store NFT
      await zkBNB.testWithdrawOrStoreNFT(withdrawOp);

      expect(await mockNftFactory.ownerOf(mockNftIndex)).to.equal(acc1.address);
      expect(await mockNftFactory.balanceOf(acc1.address)).to.equal(1);
    });
  });

  describe('withdraw NFT on mint failure', async function () {
    const nftIndex = 2;
    let withdrawOp2;

    before(async function () {
      mockNftFactory.mintFromZkBNB.reverts();
    });

    it('store pending withdrawn NFT on mint failure', async function () {
      withdrawOp2 = {
        accountIndex: 1,
        creatorAccountIndex: 0,
        creatorTreasuryRate: 5,
        nftIndex,
        collectionId: 0,
        toAddress: acc2.address,
        creatorAddress: owner.address,
        nftContentHash: mockHash,
        nftContentType: 0,
      };

      await expect(await zkBNB.testWithdrawOrStoreNFT(withdrawOp2))
        .to.emit(zkBNB, 'WithdrawalNFTPending')
        .withArgs(nftIndex);

      const result = await zkBNB.getPendingWithdrawnNFT(nftIndex);

      assert.deepStrictEqual(withdrawOp2, {
        accountIndex: result['accountIndex'],
        creatorAccountIndex: result['creatorAccountIndex'],
        creatorTreasuryRate: result['creatorTreasuryRate'],
        nftIndex: result['nftIndex'],
        collectionId: result['collectionId'],
        toAddress: result['toAddress'],
        creatorAddress: result['creatorAddress'],
        nftContentHash: result['nftContentHash'],
        nftContentType: result['nftContentType'],
      });
    });

    it('the NFT should not be minted', async function () {
      await zkBNB.testWithdrawOrStoreNFT(withdrawOp2);
      const nftKey = ethers.utils.keccak256(abi.encode(['address', 'uint256'], [mockNftFactory.address, nftIndex]));
      const l2Nft = await zkBNB.getMintedL2NftInfo(nftKey);

      assert.equal(l2Nft['nftContentHash'], 0);
      assert.equal(l2Nft['nftIndex'], 0);
    });

    it('withdraw should succeed on retry', async function () {
      await zkBNB.testWithdrawOrStoreNFT(withdrawOp2);
      mockNftFactory.mintFromZkBNB.returns();

      await expect(await zkBNB.withdrawPendingNFTBalance(nftIndex))
        .to.emit(zkBNB, 'WithdrawNft')
        .withArgs(1, mockNftFactory.address, acc2.address, nftIndex);

      expect(await mockNftFactory.ownerOf(nftIndex)).to.equal(acc2.address);
      expect(await mockNftFactory.balanceOf(acc2.address)).to.equal(1);
    });

    it('the NFT should be minted after withdrawal', async function () {
      mockNftFactory.mintFromZkBNB.returns();
      await zkBNB.testWithdrawOrStoreNFT(withdrawOp2);
      await zkBNB.withdrawPendingNFTBalance(nftIndex);

      const nftKey = ethers.utils.keccak256(abi.encode(['address', 'uint256'], [mockNftFactory.address, nftIndex]));
      const result = await zkBNB.getMintedL2NftInfo(nftKey);

      assert.equal(result['nftContentHash'], mockHash);
      assert.equal(result['nftIndex'], nftIndex);
    });

    it('the NFT should not be pending after withdrawal', async function () {
      mockNftFactory.mintFromZkBNB.returns();
      await zkBNB.testWithdrawOrStoreNFT(withdrawOp2);
      await zkBNB.withdrawPendingNFTBalance(nftIndex);
      const result = await zkBNB.getPendingWithdrawnNFT(nftIndex);
      assert.equal(result['nftContentHash'], 0);
      assert.equal(result['nftIndex'], 0);
    });
  });

  describe('deposit NFT', async function () {
    const nftL1TokenId = 0;
    const mockNftIndex = 0;
    const accountIndex = 0;
    let withdrawOp;

    before(async () => {
      withdrawOp = {
        accountIndex,
        creatorAccountIndex: 0,
        creatorTreasuryRate: 5,
        nftIndex: mockNftIndex,
        collectionId: 0,
        gasFeeAccountIndex: 1,
        toAddress: acc1.address,
        creatorAddress: owner.address,
        nftContentHash: mockHash,
        nftContentType: 0,
      };
    });

    it('deposit the 1st withdrawn NFT', async function () {
      await mockNftFactory.connect(acc1).setApprovalForAll(zkBNB.address, true);
      await expect(await zkBNB.desertMode()).to.equal(false);
      await expect(await zkBNB.connect(acc1).depositNft(acc2.address, mockNftFactory.address, nftL1TokenId))
        .to.emit(zkBNB, 'DepositNft')
        .withArgs(acc2.address, mockHash, mockNftFactory.address, nftL1TokenId, 0);
    });

    it('the deposit priority request should be added', async function () {
      const firstPriorityRequestId = await zkBNB.firstPriorityRequestId();
      const totalOpenPriorityRequests = await zkBNB.totalOpenPriorityRequests();
      const depositRequestId = firstPriorityRequestId + totalOpenPriorityRequests - 1;

      const { hashedPubData: _hashedPubData, txType: _txType } = await zkBNB.getPriorityRequest(depositRequestId);

      const expectPubData = ethers.utils.solidityPack(
        ['uint8', 'uint32', 'uint32', 'uint16', 'uint40', 'uint16', 'address', 'bytes32', 'uint8'],
        [
          3,
          0,
          withdrawOp.creatorAccountIndex,
          withdrawOp.creatorTreasuryRate,
          withdrawOp.nftIndex,
          withdrawOp.collectionId,
          acc2.address,
          withdrawOp.nftContentHash,
          0,
        ],
      );
      const expectHashedPubData = ethers.utils.keccak256(expectPubData);
      assert.equal(_hashedPubData, ethers.utils.hexDataSlice(expectHashedPubData, 12)); // bytes32 -> bytes20

      assert.equal(_txType, 3);
    });

    it('should fail to deposit a NFT which is not created by layer2', async function () {
      const mock721 = await smock.fake('ZkBNBRelatedERC721');
      mock721.ownerOf.returns(zkBNB.address);

      expect(zkBNB.depositNft('_accountName', mock721.address, '2')).to.be.revertedWith('l1 nft is not allowed');
    });
  });

  describe('Request full exit NFT', async function () {
    const nftIndex = 0; // owned by acc1
    const mockNftIndex = 0;
    const accountIndex = 0;
    let withdrawOp;

    before(async () => {
      withdrawOp = {
        // WithdrawNft
        accountIndex,
        creatorAccountIndex: 0,
        creatorTreasuryRate: 5,
        nftIndex: mockNftIndex,
        collectionId: 0,
        gasFeeAccountIndex: 1,
        toAddress: acc1.address,
        creatorAddress: owner.address,
        nftContentHash: mockHash,
        nftContentType: 0,
      };

      await expect(await zkBNB.testWithdrawOrStoreNFT(withdrawOp))
        .to.emit(zkBNB, 'WithdrawNft')
        .withArgs(accountIndex, mockNftFactory.address, acc1.address, mockNftIndex);
    });

    it('should be able to request full exit Nft', async function () {
      await zkBNB.connect(acc1).requestFullExitNft(accountIndex, nftIndex);
    });

    it('check pubdata of full exit request', async function () {
      const firstPriorityRequestId = await zkBNB.firstPriorityRequestId();
      const totalOpenPriorityRequests = await zkBNB.totalOpenPriorityRequests();
      const fullExitRequestId = firstPriorityRequestId + totalOpenPriorityRequests - 1;
      const { hashedPubData: _hashedPubData, txType: _txType } = await zkBNB.getPriorityRequest(fullExitRequestId);

      const expectPubData = ethers.utils.solidityPack(
        ['uint8', 'uint32', 'uint32', 'uint16', 'uint40', 'uint16', 'address', 'address', 'bytes32', 'uint8'],
        [
          13, // tx type
          0, // account index
          0, // creator account index
          0, // creator treasury rate
          nftIndex,
          0, // collection id
          acc1.address, // owner address
          ethers.constants.AddressZero, // creator address
          ethers.utils.hexZeroPad('0x0'.toLowerCase(), 32), // nft content hash
          0,
        ],
      );
      const expectHashedPubData = ethers.utils.keccak256(expectPubData);
      assert.equal(_hashedPubData, ethers.utils.hexDataSlice(expectHashedPubData, 12)); // bytes32 -> bytes20

      assert.equal(_txType, 13);
    });
  });

  describe('ZkBNBNFTFactory', function () {
    const tokenId = 2;

    //A pinned CID on the IPFS network
    const base16CID = new CID('bafybeibvpgysop4uafzp5ptswc73khav6spshzkyzj7qhx52fwl5qkd2ga').toString('base16');

    //The SHA2-256 digest of the IPFS multihash. This is the second part of the CIDv1
    const digestInHexFromCID = '0x' + base16CID.substring(9);

    //Convert to bytes32
    const IPFSMultiHashDigest = ethers.utils.hexZeroPad(digestInHexFromCID, 32);

    it('mint from ZkBNB using a IPFS CID Hash', async function () {
      const tokenURI = await governance.getNftTokenURI(0, IPFSMultiHashDigest);
      const extraData = ethers.constants.HashZero;

      expect(
        zkBNBNFTFactory.mintFromZkBNB(acc1.address, acc2.address, tokenId, tokenURI, extraData),
      ).to.be.revertedWith('only zkbnbAddress');
      await expect(
        await zkBNB.mintNFT(
          zkBNBNFTFactory.address,
          acc1.address,
          acc2.address,
          tokenId,
          tokenURI,
          ethers.constants.HashZero,
        ),
      )
        .to.emit(zkBNBNFTFactory, 'MintNFTFromZkBNB')
        .withArgs(acc1.address, acc2.address, tokenId, extraData);
      assert.strictEqual(await zkBNBNFTFactory.tokenURI(tokenId), tokenURI);
    });

    // // delete contentHash map
    // it.skip('check contentHash, and creator after mint', async function () {
    //   await expect(await zkBNBNFTFactory.getContentHash(tokenId)).to.be.equal(IPFSMultiHashDigest);
    //   assert(await zkBNBNFTFactory.getCreator(tokenId), acc1.address);
    // });

    // //This test is skipped as it depends on the network. However, individually, this should still work
    // it.skip('should return proper IPFS compatible tokenURI for a NFT', async function () {
    //   await expect(zkBNBNFTFactory.tokenURI(99)).to.be.revertedWith('tokenId not exist');
    //   const expectUri = `${baseURI}${mockHash.substring(2)}`;
    //   await expect(await zkBNBNFTFactory.tokenURI(tokenId)).to.be.equal(expectUri);

    //   const queryableResource = `${baseURI}`.split('//')[1] + `${mockHash.substring(2)}`;

    //   //Check if the tokenURI is indeed valid using a IPFS gateway
    //   const res = JSON.parse(await request('GET', `http://ipfs.io/ipfs/${queryableResource}`).getBody('utf8'));
    //   assert(res.name, '2 nft.storage store test');
    //   assert(res.description, '2 Using the nft.storage metadata API to create ERC-1155 compatible metadata.');
    // });

    // // change updateBaseURI to governance
    // it.skip('should point base URI to represent URI and encoding of the CID', async function () {
    //   const newBase = 'ipfs://dbvKFHFH'; //Change the encoding prefix to a different value
    //   await zkBNBNFTFactory.updateBaseUri(newBase);
    //   await expect(await zkBNBNFTFactory._base()).to.be.equal(newBase);
    // });

    // // change updateBaseURI to governance
    // it.skip('non-owner should fail to update base URI', async function () {
    //   const newBase = 'bar://';
    //   await expect(zkBNBNFTFactory.connect(acc2).updateBaseUri(newBase)).to.be.revertedWith('Only callable by owner');
    // });
  });
});
