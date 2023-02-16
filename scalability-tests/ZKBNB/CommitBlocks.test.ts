import { ethers } from 'hardhat';
import chai, { assert } from 'chai';
import { smock } from '@defi-wonderland/smock';
import { BlockCreationFactory } from '../blockCreationFactory';

chai.use(smock.matchers);

describe('ZKBNB', function () {
  let mockGovernance;
  let mockZkBNBVerifier;
  let mockZNSController;
  let mockPublicResolver;
  let mockERC20;
  let mockERC721;
  let mockNftFactory;
  let zkBNB;
  let additionalZkBNB;
  let owner, addr1, addr2, addr3, addr4;
  const accountNameHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('accountNameHash'));

  const genesisStateRoot = ethers.utils.formatBytes32String('genesisStateRoot');
  let factory: BlockCreationFactory;

  // `ZkBNB` needs to link to library `Utils` before deployed
  let utils;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

    mockGovernance = await smock.fake('Governance');
    mockZkBNBVerifier = await smock.fake('ZkBNBVerifier');
    mockZNSController = await smock.fake('ZNSController');
    mockPublicResolver = await smock.fake('PublicResolver');
    mockERC20 = await smock.fake('ERC20');
    mockERC721 = await smock.fake('ERC721');

    mockNftFactory = await smock.fake('ZkBNBNFTFactory');

    const Utils = await ethers.getContractFactory('Utils');
    utils = await Utils.deploy();
    await utils.deployed();

    const AdditionalZkBNB = await ethers.getContractFactory('AdditionalZkBNBTest');
    additionalZkBNB = await AdditionalZkBNB.deploy();
    await additionalZkBNB.deployed();

    const ZkBNB = await ethers.getContractFactory('ZkBNBTest', {
      libraries: {
        Utils: utils.address,
      },
    });
    zkBNB = await ZkBNB.deploy();
    await zkBNB.deployed();

    const initParams = ethers.utils.defaultAbiCoder.encode(
      ['address', 'address', 'address', 'address', 'address', 'bytes32'],
      [
        mockGovernance.address,
        mockZkBNBVerifier.address,
        additionalZkBNB.address,
        mockZNSController.address,
        mockPublicResolver.address,
        genesisStateRoot,
      ],
    );
    await zkBNB.initialize(initParams);

    await zkBNB.setDefaultNFTFactory(mockNftFactory.address);
    factory = new BlockCreationFactory(zkBNB, additionalZkBNB, owner);
  });

  it('accepts commit block of various sizes with register ZNS operations', async () => {
    mockZNSController.registerZNS.returns([accountNameHash, 1]);
    await factory.createZNSAccountNameTx();
    await factory.createZNSAccountNameTx();
    await factory.createZNSAccountNameTx();
    factory.markBlockFinish();
    await factory.createZNSAccountNameTx();
    await factory.createZNSAccountNameTx();
    factory.markBlockFinish();
    await factory.commitAndFlushAllBlocks();
    await factory.createZNSAccountNameTx();
    factory.markBlockFinish();
    await factory.commitAndFlushAllBlocks();
  });

  it('accepts commit block of various sizes with depositBNB operations', async () => {
    mockZNSController.getSubnodeNameHash.returns(accountNameHash);
    mockZNSController.isRegisteredNameHash.returns(true);

    //Create blocks
    await factory.createDepositBNBTx();
    await factory.createDepositBNBTx();
    await factory.createDepositBNBTx();
    factory.markBlockFinish();
    await factory.createDepositBNBTx();
    factory.markBlockFinish();
    await factory.commitAndFlushAllBlocks();
  });

  it('accepts commit blocks of various sizes with mix of transactions', async () => {
    mockZNSController.getSubnodeNameHash.returns(accountNameHash);
    mockZNSController.isRegisteredNameHash.returns(true);
    mockZNSController.registerZNS.returns([accountNameHash, 1]);

    await factory.createZNSAccountNameTx();
    const block1Size = factory.markBlockFinish();
    await factory.commitAndFlushAllBlocks();
    await factory.createZNSAccountNameTx();
    await factory.createZNSAccountNameTx();
    const block2Size = factory.markBlockFinish();
    await factory.commitAndFlushAllBlocks();
    await factory.createZNSAccountNameTx();
    await factory.createDepositBNBTx();
    await factory.createDepositBNBTx();
    const block3Size = factory.markBlockFinish();
    await factory.commitAndFlushAllBlocks();
    console.log('Finished committing blocks of sizes %s %s %s in order', block1Size, block2Size, block3Size);
  });

  it('accepts 15 commit blocks of size 10 each in one go', async () => {
    mockZNSController.registerZNS.returns([accountNameHash, 1]);

    for (let block = 0; block < 15; block++) {
      for (let tx = 0; tx < 10; tx++) {
        await factory.createZNSAccountNameTx();
      }
      const blockSize = factory.markBlockFinish();
      assert(blockSize == 10);
    }
    await factory.commitAndFlushAllBlocks();
  });

  it('accepts 5 commit blocks of size 50 each in one go', async () => {
    mockZNSController.registerZNS.returns([accountNameHash, 1]);

    for (let block = 0; block < 15; block++) {
      for (let tx = 0; tx < 10; tx++) {
        await factory.createZNSAccountNameTx();
      }
      const blockSize = factory.markBlockFinish();
      assert(blockSize == 10);
    }
    await factory.commitAndFlushAllBlocks();
  });
});
