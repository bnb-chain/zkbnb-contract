import { ethers } from 'hardhat';
import { smock } from '@defi-wonderland/smock';

describe('AdditionalZkBNB', function () {
  let additionalZkBNB; // AdditionalZkBNBTest.sol
  let owner;

  before(async function () {
    [owner] = await ethers.getSigners();

    const MockGovernance = await smock.mock('Governance');
    const mockGovernance = await MockGovernance.deploy();
    await mockGovernance.deployed();
    await mockGovernance.setVariable('networkGovernor', owner.address);

    const Utils = await ethers.getContractFactory('Utils');
    const utils = await Utils.deploy();
    await utils.deployed();

    const AdditionalZkBNB = await ethers.getContractFactory('AdditionalZkBNBTest', {
      libraries: {
        Utils: utils.address,
      },
    });
    additionalZkBNB = await AdditionalZkBNB.deploy(mockGovernance.address);
    await additionalZkBNB.deployed();
  });
});
