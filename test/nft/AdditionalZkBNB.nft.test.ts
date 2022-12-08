import { ethers } from 'hardhat';
import { assert, expect } from 'chai';
import { smock } from '@defi-wonderland/smock';

describe('AdditionalZkBNB', function () {
  let mockZNSController;
  let mockNftFactory;

  let additionalZkBNB; // AdditionalZkBNBTest.sol
  let owner, acc1;

  const HashZero = ethers.constants.HashZero;

  before(async function () {
    [owner, acc1] = await ethers.getSigners();

    const MockZNSController = await smock.mock('ZNSController');
    mockZNSController = await MockZNSController.deploy();
    await mockZNSController.deployed();

    const MockGovernance = await smock.mock('Governance');
    const mockGovernance = await MockGovernance.deploy();
    await mockGovernance.deployed();
    await mockGovernance.setVariable('networkGovernor', owner.address);

    mockNftFactory = await smock.fake('ZkBNBNFTFactory');

    const AdditionalZkBNB = await ethers.getContractFactory('AdditionalZkBNBTest');
    additionalZkBNB = await AdditionalZkBNB.deploy(mockZNSController.address, mockGovernance.address);
    await additionalZkBNB.deployed();
  });

  it('register NFT factory', async function () {
    const creatorAccountName = 'bar';
    const collectionId = 0;
    mockZNSController.isRegisteredNameHash.returns(true);
    mockZNSController.getOwner.returns(owner.address);

    const creatorAccountNameHash = await mockZNSController.getSubnodeNameHash(creatorAccountName);

    await expect(await additionalZkBNB.registerNFTFactory(creatorAccountName, collectionId, mockNftFactory.address))
      .to.emit(additionalZkBNB, 'NewNFTFactory')
      .withArgs(creatorAccountNameHash, collectionId, mockNftFactory.address);

    expect(await additionalZkBNB.nftFactories(creatorAccountNameHash, 0)).to.equal(mockNftFactory.address);
  });

  it('set default NFT factory', async function () {
    await expect(await additionalZkBNB.setDefaultNFTFactory(mockNftFactory.address))
      .to.emit(additionalZkBNB, 'NewDefaultNFTFactory')
      .withArgs(mockNftFactory.address);
  });

  it('on ERC721 received', async function () {
    await additionalZkBNB.onERC721Received(owner.address, acc1.address, 0, HashZero);
  });
});
