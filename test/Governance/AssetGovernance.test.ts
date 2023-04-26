import chai, { expect } from 'chai';

import { ethers } from 'hardhat';
import { FakeContract, smock } from '@defi-wonderland/smock';
import { beforeEach } from 'mocha';

chai.use(smock.matchers);

describe('AssetGovernance', function () {
  let assetGovernance;
  let deployReceipt;
  let owner, addr1, addr2, addr3;
  let mockGovernance: FakeContract;
  let mockListingToken: FakeContract;
  let mockAssetsToken: FakeContract;

  const listingCap = 5;
  const listingFee = ethers.utils.parseEther('100');
  let treasury;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    treasury = addr1.address;

    mockGovernance = await smock.fake('Governance');
    mockListingToken = await smock.fake('ERC20');
    mockAssetsToken = await smock.fake('ERC20');

    const AssetGovernance = await ethers.getContractFactory('AssetGovernance');
    assetGovernance = await AssetGovernance.deploy(
      mockGovernance.address,
      mockListingToken.address,
      listingFee,
      listingCap,
      treasury,
    );
    await assetGovernance.deployed();

    mockGovernance.requireGovernor.returns();

    const deployTx = await assetGovernance.deployTransaction;
    deployReceipt = await deployTx.wait();
  });

  it('should only token lister can add assets', async function () {
    mockGovernance.totalAssets.returns(listingCap - 1);

    await expect(assetGovernance.addAsset(mockAssetsToken.address)).to.revertedWith('no access');
    await expect(assetGovernance.connect(addr1).addAsset(mockAssetsToken.address)).not.to.reverted;
  });

  describe('any address can add assets', () => {
    beforeEach(async function () {
      await assetGovernance.setLister(ethers.constants.AddressZero, true);
    });

    it('should be able to add assets by any address', async function () {
      mockGovernance.totalAssets.returns(listingCap - 1);
      mockListingToken.transferFrom.returns(true);

      await expect(assetGovernance.addAsset(mockAssetsToken.address)).not.to.reverted;
    });
    it('should emit TokenListerUpdate event', async function () {
      const event = deployReceipt.events?.filter(({ event }) => {
        return event == 'TokenListerUpdate';
      });
      expect(event[0].args.tokenLister).to.be.equal(addr1.address);
    });
    it('should reverted if total assets exceeds the limit', async () => {
      mockGovernance.totalAssets.returns(listingCap + 1);

      await expect(assetGovernance.addAsset(mockAssetsToken.address)).to.revertedWith("can't add more tokens");
    });

    it('should be able to take a listing fee when adding a new asset', async () => {
      mockGovernance.totalAssets.returns(listingCap - 1);

      mockListingToken.transferFrom.returns(true);
      mockListingToken.transferFrom.returns(true);
      await assetGovernance.addAsset(mockAssetsToken.address);
      expect(mockListingToken.transferFrom).to.have.been.calledWith(owner.address, treasury, listingFee);
    });

    it('should only call by governance', async () => {
      // make all ready
      mockGovernance.requireGovernor.reverts();

      await expect(assetGovernance.connect(addr3).setLister(mockAssetsToken.address)).to.reverted;
      await expect(assetGovernance.connect(addr3).setListingCap(listingCap + 2)).to.reverted;
      await expect(assetGovernance.connect(addr3).setListingFee(listingFee)).to.reverted;
      await expect(assetGovernance.connect(addr3).setListingFeeAsset(mockAssetsToken.address, listingFee)).to.reverted;
      await expect(assetGovernance.connect(addr3).setTreasury(addr2.address)).to.reverted;
    });

    describe('update properties', () => {
      it('should be able to change listing token and fee ', async () => {
        const mockNewListingToken = await smock.fake('ERC20');
        const newListingFee = ethers.utils.parseEther('50');

        await expect(assetGovernance.setListingFeeAsset(mockNewListingToken.address, newListingFee))
          .to.emit(assetGovernance, 'ListingFeeTokenUpdate')
          .withArgs(mockNewListingToken.address, newListingFee);

        const listingFee = await assetGovernance.listingFee();
        const listingFeeToken = await assetGovernance.listingFeeToken();

        expect(listingFee).to.be.equal(newListingFee);
        expect(listingFeeToken).to.be.equal(mockNewListingToken.address);
      });

      it('should able to change listing fee', async () => {
        const newListingFee = ethers.utils.parseEther('50');

        await expect(assetGovernance.setListingFee(newListingFee))
          .to.emit(assetGovernance, 'ListingFeeUpdate')
          .withArgs(newListingFee);

        const listingFee = await assetGovernance.listingFee();
        expect(listingFee).to.be.equal(newListingFee);
      });

      it('should able to change lister', async () => {
        const newListingFee = ethers.utils.parseEther('50');

        await expect(assetGovernance.setListingFee(newListingFee))
          .to.emit(assetGovernance, 'ListingFeeUpdate')
          .withArgs(newListingFee);

        const listingFee = await assetGovernance.listingFee();
        expect(listingFee).to.be.equal(newListingFee);
      });

      it('should able to change listing cap', async () => {
        mockGovernance.totalAssets.returns(listingCap + 1);
        mockListingToken.transferFrom.returns(true);

        await expect(assetGovernance.addAsset(mockAssetsToken.address)).to.revertedWith("can't add more tokens");
        await assetGovernance.setListingCap(listingCap + 2);
        await expect(assetGovernance.addAsset(mockAssetsToken.address)).to.not.reverted;
      });

      it('should able to change treasury', async () => {
        mockGovernance.totalAssets.returns(listingCap - 1);
        mockListingToken.transferFrom.returns(true);

        await assetGovernance.setTreasury(addr2.address);
        await assetGovernance.addAsset(mockAssetsToken.address);
        expect(mockListingToken.transferFrom).to.have.been.calledWith(owner.address, addr2.address, listingFee);
      });

      it('should able to set lister ', async () => {
        let isAlive = await assetGovernance.tokenLister(treasury);
        expect(isAlive).to.be.equal(true);

        await expect(assetGovernance.setLister(treasury, false));
        expect(isAlive).to.be.equal(true).to.emit(assetGovernance, 'TokenListerUpdate').withArgs(treasury, false);

        isAlive = await assetGovernance.tokenLister(treasury);
        expect(isAlive).to.be.equal(false);
      });
    });
  });
});
