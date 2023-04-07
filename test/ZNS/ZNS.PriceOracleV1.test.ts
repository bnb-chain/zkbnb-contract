import { expect } from 'chai';
import { ethers } from 'hardhat';

describe('Price Oracle V1', function () {
  let oracle;

  beforeEach(async function () {
    const PriceOracleV1 = await ethers.getContractFactory('PriceOracleV1');
    oracle = await PriceOracleV1.deploy(ethers.utils.parseEther('0.05'));
    await oracle.deployed();
  });

  it('should charge 0.05 BNB for names of size 1-6', async function () {
    const EXPECTED_PRICE = ethers.utils.parseEther('0.05');
    expect(await oracle.price('a')).to.equal(EXPECTED_PRICE);
    expect(await oracle.price('ti')).to.equal(EXPECTED_PRICE);
    expect(await oracle.price('ola')).to.equal(EXPECTED_PRICE);
    expect(await oracle.price('d2ac')).to.equal(EXPECTED_PRICE);
    expect(await oracle.price('dd93d')).to.equal(EXPECTED_PRICE);
    expect(await oracle.price('39993b')).to.equal(EXPECTED_PRICE);
    expect(await oracle.price('cdg5rh3')).to.equal(0);
  });

  it('should be able to change price for small names', async function () {
    const EXPECTED_PRICE = ethers.utils.parseEther('0.05');
    const NEW_PRICE = ethers.utils.parseEther('0.5');
    expect(await oracle.price('d2ac')).to.equal(EXPECTED_PRICE);
    expect(await oracle.price('1234567')).to.equal(0);

    await expect(oracle.changePrice(NEW_PRICE)).to.emit(oracle, 'PriceChanged').withArgs(NEW_PRICE);
    expect(await oracle.price('d2ac')).to.equal(NEW_PRICE);
    expect(await oracle.price('1234567')).to.equal(0);
  });

  it('should be free for names of size >6 chars', async function () {
    expect(await oracle.price('1234567')).to.equal(0);
    expect(await oracle.price('ddb445hhds4')).to.equal(0);
  });

  it('should revert for improper names', async function () {
    await expect(oracle.price('')).to.be.revertedWith('invalid name');
    await expect(oracle.price('@')).to.be.revertedWith('invalid name');
    await expect(oracle.price('3_b')).to.be.revertedWith('invalid name');
    await expect(oracle.price("'")).to.be.revertedWith('invalid name');
    await expect(oracle.price('d*(_3')).to.be.revertedWith('invalid name');
    await expect(oracle.price('DM33gg')).to.be.revertedWith('invalid name');
    await expect(oracle.price('D*l3kv')).to.be.revertedWith('invalid name');
  });
});
