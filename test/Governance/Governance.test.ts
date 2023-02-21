import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { assert, expect } from 'chai';
import { Wallet } from 'ethers';

import { ethers } from 'hardhat';
import { transferFunds } from '../util';
import { FakeContract, smock } from '@defi-wonderland/smock';
import { BUSD_ASSET_ADDRESS, NEW_ASSET_ADDRESS, NULL_ADDRESS, VALIDATOR_ADDRESS } from '../constants';
import { beforeEach } from 'mocha';

describe('Governance', function () {
  let governance;
  let owner;
  let addr1;
  let addr2;
  let addr3;
  let governerWallet: Wallet;
  let mockAssetGovernance: FakeContract;
  let mockZkBNB: FakeContract;

  beforeEach('init Wallets', async function () {
    const signers: SignerWithAddress[] = await ethers.getSigners();
    owner = signers[0];
    addr1 = signers[1];
    addr2 = signers[2];
    addr3 = signers[3];
    governerWallet = ethers.Wallet.createRandom().connect(owner.provider);
    await transferFunds(owner, await governerWallet.getAddress(), '1000000');

    const GOVERNANCE = await ethers.getContractFactory('Governance');
    governance = await GOVERNANCE.deploy();
    await governance.deployed();

    mockAssetGovernance = await smock.fake('AssetGovernance');
    mockZkBNB = await smock.fake('ZkBNB');
  });

  it('should be able to initialize with a EOA Governer', async function () {
    const abi = ethers.utils.defaultAbiCoder;
    const byteAddr = abi.encode(['address'], [await governerWallet.getAddress()]);
    await governance.initialize(byteAddr);
    expect(await governance.networkGovernor()).to.equal(await governerWallet.getAddress());
  });

  it('BNB asset should have null address and have Id 0', async function () {
    const abi = ethers.utils.defaultAbiCoder;
    const byteAddr = abi.encode(['address'], [await governerWallet.getAddress()]);
    await governance.initialize(byteAddr);
    expect(await governance.networkGovernor()).to.equal(await governerWallet.getAddress());
    expect(await governance.assetAddresses(0)).to.equal(NULL_ADDRESS);
    expect(await governance.assetsList(NULL_ADDRESS)).to.equal(0);
  });

  describe('After a governer is set', function () {
    beforeEach('initialize Governer', async function () {
      const abi = ethers.utils.defaultAbiCoder;
      const byteAddr = abi.encode(['address'], [await governerWallet.getAddress()]);
      await governance.initialize(byteAddr);
    });

    it('should be able to change Governer if called by current Governer', async function () {
      const newGovernor = ethers.Wallet.createRandom();
      const tx = await governance.connect(governerWallet).changeGovernor(await newGovernor.getAddress());
      const rc = await tx.wait();
      const event = rc.events.find((event) => event.event === 'NewGovernor');
      const [newGovernorAddress] = event.args;

      assert(newGovernorAddress === (await newGovernor.getAddress()));
      expect(await governance.networkGovernor()).to.equal(await newGovernor.getAddress());
    });

    it('should be able to set a new asset Governance contract if called by current Governer', async function () {
      const tx = await governance.connect(governerWallet).changeAssetGovernance(mockAssetGovernance.address);
      const rc = await tx.wait();
      const event = rc.events.find((event) => event.event === 'NewAssetGovernance');
      const [newAssetGovernanceAddress] = event.args;

      assert(newAssetGovernanceAddress === mockAssetGovernance.address);
      expect(await governance.assetGovernance()).to.equal(mockAssetGovernance.address);
    });

    it('should be able to pause an asset if called by current Governer', async function () {
      // We need to set a asset Governance contract to create an asset but the pause/ unpause actions are controlled by governer
      await governance.connect(governerWallet).changeAssetGovernance(mockAssetGovernance.address);
      const contractSigner = await ethers.getSigner(mockAssetGovernance.address);
      await transferFunds(owner, mockAssetGovernance.address, '1');
      await governance.connect(contractSigner).addAsset(BUSD_ASSET_ADDRESS);

      const tx = await governance.connect(governerWallet).setAssetPaused(BUSD_ASSET_ADDRESS, true);
      const rc = await tx.wait();
      const event = rc.events.find((event) => event.event === 'AssetPausedUpdate');
      const [assetAddress, isPaused] = event.args;

      assert(assetAddress === BUSD_ASSET_ADDRESS);
      assert(isPaused === true);
    });

    it('should be able to unpause an asset if called by current Governer', async function () {
      // We need to set a asset Governance contract to create an asset but the pause/ unpause actions are controlled by governer
      await governance.connect(governerWallet).changeAssetGovernance(mockAssetGovernance.address);
      const contractSigner = await ethers.getSigner(mockAssetGovernance.address);
      await transferFunds(owner, mockAssetGovernance.address, '1');
      await governance.connect(contractSigner).addAsset(BUSD_ASSET_ADDRESS);
      await governance.connect(governerWallet).setAssetPaused(BUSD_ASSET_ADDRESS, true);
      await expect(governance.connect(governerWallet).validateAssetAddress(BUSD_ASSET_ADDRESS)).to.be.revertedWith(
        '2i',
      );

      const tx = await governance.connect(governerWallet).setAssetPaused(BUSD_ASSET_ADDRESS, false);
      const rc = await tx.wait();
      const event = rc.events.find((event) => event.event === 'AssetPausedUpdate');
      const [assetAddress, isPaused] = event.args;
      assert(assetAddress === BUSD_ASSET_ADDRESS);
      assert(isPaused === false);
    });

    //TODO: What's the point of these controls?
    it('should be able to turn validators on/off if called by current Governer', async function () {
      const tx = await governance.connect(governerWallet).setValidator(VALIDATOR_ADDRESS, true);
      const rc = await tx.wait();
      const event = rc.events.find((event) => event.event === 'ValidatorStatusUpdate');
      const [validatorAddress, isActive] = event.args;

      assert(validatorAddress === VALIDATOR_ADDRESS);
      assert(isActive === true);
    });

    it('should revert if is not validator ', async function () {
      await governance.connect(governerWallet).setValidator(VALIDATOR_ADDRESS, true);
      await expect(governance.isActiveValidator(owner.address)).to.be.revertedWith('invalid validator');
    });

    describe('After a new Asset Governance contract is set', function () {
      beforeEach('set new Asset Governance contract', async function () {
        await governance.connect(governerWallet).changeAssetGovernance(mockAssetGovernance.address);
      });

      it('governer should be able to change the governance contract again', async function () {
        const newmockAssetGovernance = await smock.fake('AssetGovernance');
        const tx = await governance.connect(governerWallet).changeAssetGovernance(newmockAssetGovernance.address);
        const rc = await tx.wait();
        const event = rc.events.find((event) => event.event === 'NewAssetGovernance');
        const [newAssetGovernanceAddress] = event.args;

        assert(newAssetGovernanceAddress === newmockAssetGovernance.address);
        expect(await governance.assetGovernance()).to.equal(newmockAssetGovernance.address);
      });

      it('should be able to add BUSD stable asset first if called by the asset Governance contract', async function () {
        const contractSigner = await ethers.getSigner(mockAssetGovernance.address);
        await transferFunds(owner, mockAssetGovernance.address, '1');
        const tx = await governance.connect(contractSigner).addAsset(BUSD_ASSET_ADDRESS);
        const rc = await tx.wait();
        const event = rc.events.find((event) => event.event === 'NewAsset'); //Event is not emitted for the BUSD asset address

        assert(event === undefined);
        expect(await governance.totalAssets()).to.equal(1);
        expect(await governance.assetsList(BUSD_ASSET_ADDRESS)).to.equal(1);
        expect(await governance.assetAddresses(1)).to.equal(BUSD_ASSET_ADDRESS);
      });

      it('should be able to add a new asset after BUSD address is set and only if called by the asset Governance contract', async function () {
        const contractSigner = await ethers.getSigner(mockAssetGovernance.address);
        await transferFunds(owner, mockAssetGovernance.address, '1');
        await governance.connect(contractSigner).addAsset(BUSD_ASSET_ADDRESS); //Set BUSD as first asset

        const tx = await governance.connect(contractSigner).addAsset(NEW_ASSET_ADDRESS);
        const rc = await tx.wait();
        const event = rc.events.find((event) => event.event === 'NewAsset');
        const [newAssetAddress, newAssetId] = event.args;

        assert(newAssetAddress === NEW_ASSET_ADDRESS);
        expect(await governance.totalAssets()).to.equal(2);
        expect(await governance.assetsList(NEW_ASSET_ADDRESS)).to.equal(2);
        expect(await governance.assetAddresses(2)).to.equal(NEW_ASSET_ADDRESS);
      });

      it('should be able to add a new asset after BUSD address is set and only if called by the asset Governance contract', async function () {
        const contractSigner = await ethers.getSigner(mockAssetGovernance.address);
        await transferFunds(owner, mockAssetGovernance.address, '1');
        await governance.connect(contractSigner).addAsset(BUSD_ASSET_ADDRESS); //Set BUSD as first asset

        const tx = await governance.connect(contractSigner).addAsset(NEW_ASSET_ADDRESS);
        const rc = await tx.wait();
        const event = rc.events.find((event) => event.event === 'NewAsset');
        const [newAssetAddress, newAssetId] = event.args;

        assert(newAssetAddress === NEW_ASSET_ADDRESS);
        expect(await governance.totalAssets()).to.equal(2);
        expect(await governance.assetsList(NEW_ASSET_ADDRESS)).to.equal(2);
        expect(await governance.assetAddresses(2)).to.equal(NEW_ASSET_ADDRESS);
      });

      it('should not be able to add a new asset address twice', async function () {
        const contractSigner = await ethers.getSigner(mockAssetGovernance.address);
        await transferFunds(owner, mockAssetGovernance.address, '1');
        await governance.connect(contractSigner).addAsset(BUSD_ASSET_ADDRESS); //Set BUSD as first asset
        await governance.connect(contractSigner).addAsset(NEW_ASSET_ADDRESS);

        await expect(governance.connect(contractSigner).addAsset(NEW_ASSET_ADDRESS)).to.be.revertedWith('1e');
      });

      //Skip this test as it takes >30min to complete
      it.skip('should only be able to add a max of 2 ** 16 - 2 assets', async function () {
        this.timeout(10000000);
        const contractSigner = await ethers.getSigner(mockAssetGovernance.address);
        await transferFunds(addr1, mockAssetGovernance.address, '50');
        await governance.connect(contractSigner).addAsset(BUSD_ASSET_ADDRESS); //Set BUSD as first asset

        let assetAddress;
        for (let i = 0; i < 2 ** 16 - 3; i++) {
          assetAddress = ethers.Wallet.createRandom().address;
          await governance.connect(contractSigner).addAsset(assetAddress);
        }
        await expect(governance.connect(contractSigner).addAsset(NEW_ASSET_ADDRESS)).to.be.revertedWith('1f');
      });
    });
  });

  describe('After default Nft factory is set', function () {
    let mockNftFactory;

    beforeEach('initialize Governer', async function () {
      const abi = ethers.utils.defaultAbiCoder;
      const byteAddr = abi.encode(['address'], [owner.address]);
      await governance.initialize(byteAddr);
      await governance.setZkBNBAddress(mockZkBNB.address);
      mockNftFactory = await smock.fake('ZkBNBNFTFactory');
      await expect(await governance.setDefaultNFTFactory(mockNftFactory.address))
        .to.emit(governance, 'SetDefaultNFTFactory')
        .withArgs(mockNftFactory.address);
    });

    it('register NFT factory without deploying NFT Factory', async function () {
      const mockNftFactory = await smock.fake('ZkBNBNFTFactory');
      const collectionId = 0;
      await expect(
        governance.connect(addr1).registerNFTFactory(collectionId, mockNftFactory.address),
      ).to.be.revertedWith('ws');
    });

    it('Deploy and register NFT factory', async function () {
      const collectionId = 1;
      await expect(
        await governance.connect(addr1).deployAndRegisterNFTFactory(collectionId, 'name', 'symbol', 'ipfs://f01701220'),
      ).to.emit(governance, 'NFTFactoryRegistered');

      expect((await governance.nftFactories(addr1.address, collectionId)) !== ethers.constants.AddressZero);
    });
  });
});
