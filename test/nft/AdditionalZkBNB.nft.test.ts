import { ethers } from 'hardhat';
import { assert, expect } from 'chai';
import { smock } from '@defi-wonderland/smock';

//TODO: Fix failing test cases
describe.skip('AdditionalZkBNB', function () {
  let mockZNSController;
  let mockNftFactory;

  let additionalZkBNB; // AdditionalZkBNBTest.sol
  let owner, acc1;

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

  it('set default NFT factory', async function () {
    await expect(await additionalZkBNB.setDefaultNFTFactory(mockNftFactory.address))
      .to.emit(additionalZkBNB, 'NewDefaultNFTFactory')
      .withArgs(mockNftFactory.address);
  });
});
