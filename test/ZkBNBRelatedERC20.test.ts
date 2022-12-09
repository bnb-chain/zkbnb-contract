import { ethers } from 'hardhat';
import { assert, expect } from 'chai';
import { smock } from '@defi-wonderland/smock';

describe('ZkBNBRelatedERC20', async function () {
  let zkBNBRelatedERC20;

  const initialSupply = 100;
  const name = 'bar';
  const symbol = 'BAR';

  it('create ZkBNBRelatedERC20', async function () {
    const ZkBNBRelatedERC20 = await ethers.getContractFactory('ZkBNBRelatedERC20');
    zkBNBRelatedERC20 = await ZkBNBRelatedERC20.deploy(initialSupply, name, symbol);
    await zkBNBRelatedERC20.deployed();

    expect(await zkBNBRelatedERC20.totalSupply()).to.be.equal(initialSupply);
    expect(await zkBNBRelatedERC20.name()).to.be.equal(name);
    expect(await zkBNBRelatedERC20.symbol()).to.be.equal(symbol);
  });
});
