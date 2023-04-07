import chai, { expect } from 'chai';
import { ethers } from 'hardhat';
import { smock } from '@defi-wonderland/smock';

chai.use(smock.matchers);

describe('StablePriceOracle', function () {
  let stablePriceOracle;
  let event;

  const priceLetter = [ethers.utils.parseEther('1'), ethers.utils.parseEther('2'), ethers.utils.parseEther('3')];

  beforeEach(async function () {
    const StablePriceOracle = await ethers.getContractFactory('StablePriceOracle');
    stablePriceOracle = await StablePriceOracle.deploy(priceLetter);

    await stablePriceOracle.deployed();
    const stablePriceOracleTx = await stablePriceOracle.deployTransaction;
    const receipt = await stablePriceOracleTx.wait();
    event = receipt.events?.filter(({ event }) => {
      return event == 'RentPriceChanged';
    });
  });

  it('should emit RentPriceChanged event', async function () {
    expect(event[0].args.prices[0]).to.be.equal(priceLetter[0]);
    expect(event[0].args.prices[1]).to.be.equal(priceLetter[1]);
    expect(event[0].args.prices[2]).to.be.equal(priceLetter[2]);
  });
  it('should return correct price ', async () => {
    const res1 = await stablePriceOracle.price('f');
    const res3 = await stablePriceOracle.price('fir');
    const res5 = await stablePriceOracle.price('first');
    const res10 = await stablePriceOracle.price('firstfirst');
    const res11 = await stablePriceOracle.price('firstfirstf');
    const res15 = await stablePriceOracle.price('firstfirstfirst');
    const res16 = await stablePriceOracle.price('firstfirstfirstf');

    expect(res1).to.be.equal(ethers.utils.parseEther('3'));
    expect(res3).to.be.equal(ethers.utils.parseEther('1'));
    expect(res5).to.be.equal(ethers.utils.parseEther('1'));
    expect(res10).to.be.equal(ethers.utils.parseEther('2'));
    expect(res11).to.be.equal(ethers.utils.parseEther('2'));
    expect(res15).to.be.equal(ethers.utils.parseEther('3'));
    expect(res16).to.be.equal(ethers.utils.parseEther('3'));
  });

  it('should change price', async () => {
    const newPriceLetter = [
      ethers.utils.parseEther('10'),
      ethers.utils.parseEther('20'),
      ethers.utils.parseEther('30'),
    ];

    await stablePriceOracle.changeRentPrice(newPriceLetter);

    const res1 = await stablePriceOracle.price1Letter();
    const res2 = await stablePriceOracle.price2Letter();
    const res3 = await stablePriceOracle.price3Letter();

    expect(res1).to.be.equal(newPriceLetter[0]);
    expect(res2).to.be.equal(newPriceLetter[1]);
    expect(res3).to.be.equal(newPriceLetter[2]);
  });
});
