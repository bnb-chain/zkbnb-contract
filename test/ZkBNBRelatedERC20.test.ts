import chai from 'chai';
import { ethers } from 'hardhat';
import { expect } from 'chai';
import { smock } from '@defi-wonderland/smock';
import { deployZkBNB, deployZkBNBProxy } from './util';

chai.use(smock.matchers);

describe('ZkBNBRelatedERC20', async function () {
  let zkBNBRelatedERC20;

  const initialSupply = 100;
  const name = 'bar';
  const symbol = 'BAR';

  let mockGovernance;
  let mockZkBNBVerifier;
  let mockDesertVerifier;
  let zkBNB, additionalZkBNB;

  let owner;

  beforeEach(async function () {
    [owner] = await ethers.getSigners();

    mockGovernance = await smock.fake('Governance');
    mockZkBNBVerifier = await smock.fake('ZkBNBVerifier');
    mockDesertVerifier = await smock.fake('DesertVerifier');

    const AdditionalZkBNB = await ethers.getContractFactory('AdditionalZkBNB');
    additionalZkBNB = await AdditionalZkBNB.deploy();
    await additionalZkBNB.deployed();

    const zkBNBImpl = await deployZkBNB('ZkBNBTest');

    const initParams = ethers.utils.defaultAbiCoder.encode(
      ['address', 'address', 'address', 'address', 'bytes32'],
      [
        mockGovernance.address,
        mockZkBNBVerifier.address,
        additionalZkBNB.address,
        mockDesertVerifier.address,
        '0x0000000000000000000000000000000000000000000000000000000000000000',
      ],
    );

    zkBNB = await deployZkBNBProxy(initParams, zkBNBImpl);
  });

  it('create ZkBNBRelatedERC20', async function () {
    const ZkBNBRelatedERC20 = await ethers.getContractFactory('ZkBNBRelatedERC20');
    zkBNBRelatedERC20 = await ZkBNBRelatedERC20.deploy(initialSupply, name, symbol);
    await zkBNBRelatedERC20.deployed();

    expect(await zkBNBRelatedERC20.totalSupply()).to.be.equal(initialSupply);
    expect(await zkBNBRelatedERC20.name()).to.be.equal(name);
    expect(await zkBNBRelatedERC20.symbol()).to.be.equal(symbol);
  });

  it('should be able to withdraw ERC20', async function () {
    const assetId = 2;
    const amount = 100;
    const token = zkBNBRelatedERC20.address;

    mockGovernance.validateAssetAddress.returns(assetId);
    mockGovernance.assetAddresses.returns(token);
    mockGovernance.pausedAssets.returns(false);

    await zkBNBRelatedERC20.approve(zkBNB.address, amount);
    expect(await zkBNBRelatedERC20.balanceOf(owner.address)).to.equal(amount);

    await zkBNB.depositBEP20(token, amount, owner.address);
    expect(await zkBNBRelatedERC20.balanceOf(owner.address)).to.equal(0);

    expect(await zkBNB.testWithdrawOrStore(assetId, owner.address, amount))
      .to.emit(zkBNB, 'Withdrawal')
      .withArgs(assetId, amount);
    expect(await zkBNBRelatedERC20.balanceOf(owner.address)).to.equal(amount);
  });
});
