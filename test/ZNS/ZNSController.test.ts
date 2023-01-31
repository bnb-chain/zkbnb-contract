import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { getKeccak256 } from '../util';
import { assert, expect } from 'chai';
import { ethers } from 'hardhat';
import { NON_NULL_ADDRESS, NULL_ADDRESS, X_ADDRESS, Y_ADDRESS } from '../constants';
import { smock } from '@defi-wonderland/smock';
/* eslint-disable */
const namehash = require('eth-ens-namehash');

describe('ZNSController', function () {
  let znsController;
  let owner;
  let addr1;
  let addr2;
  let addr3;
  let znsRegistry;
  let priceOracle;
  let zkbnb;
  let baseNode;

  beforeEach(async function () {
    const signers: SignerWithAddress[] = await ethers.getSigners();
    owner = signers[0];
    addr1 = signers[1];
    addr2 = signers[2];
    addr3 = signers[3];
    const ZNS = await ethers.getContractFactory('ZNSController');
    znsController = await ZNS.deploy();
    await znsController.deployed();

    const Registry = await smock.mock('ZNSRegistry');
    znsRegistry = await Registry.deploy();

    priceOracle = await smock.fake('PriceOracleV1');
    zkbnb = await smock.fake('ZkBNB');

    //How is this different from keccak256Hash?
    const baseNode = namehash.hash('zkbnb');

    const initParams = ethers.utils.defaultAbiCoder.encode(
      ['address', 'address', 'bytes32'],
      [znsRegistry.address, priceOracle.address, baseNode],
    );
    await znsController.initialize(initParams);
  });

  it('should initialize properly', async function () {
    const prices = await znsController.prices();
    expect(await znsController.prices()).to.equal(priceOracle.address);
    expect(await znsController.zns()).to.equal(znsRegistry.address);
    // No way to create a name hash locally so skipping this test here
  });

  it('should be able to add ZKBNB contract as a controller', async function () {
    await expect(znsController.addController(zkbnb.address))
      .to.emit(znsController, 'ControllerAdded')
      .withArgs(zkbnb.address);
  });

  it('should be able to remove ZKBNB contract as a controller', async function () {
    await expect(znsController.addController(zkbnb.address))
      .to.emit(znsController, 'ControllerAdded')
      .withArgs(zkbnb.address);
    await expect(znsController.removeController(zkbnb.address))
      .to.emit(znsController, 'ControllerRemoved')
      .withArgs(zkbnb.address);
  });

  it('should pause and unpause registrations when called by owner', async function () {
    assert((await znsController.isPaused()) == false);
    await znsController.pauseRegistration();
    assert((await znsController.isPaused()) == true);
    await znsController.unPauseRegistration();
    assert((await znsController.isPaused()) == false);
  });

  describe('After registering the base node with the registry', async function () {
    let pubX;
    let pubY;
    beforeEach('create base node first', async function () {
      //Register the controller on the ZNSRegistry
      const rootNode = '0x0000000000000000000000000000000000000000000000000000000000000000';
      const baseNodeLabel = getKeccak256('zkbnb');

      const setBaseNodeTx = await znsRegistry.setSubnodeOwner(
        rootNode,
        baseNodeLabel,
        znsController.address,
        ethers.constants.HashZero,
        ethers.constants.HashZero,
      );
      pubX = ethers.utils.hexZeroPad(X_ADDRESS, 32);
      pubY = ethers.utils.hexZeroPad(Y_ADDRESS, 32);
    });

    it('should be able to set a resolver for base node ie .zkbnb', async function () {
      //Get base node
      const baseNodeNameHash = await znsController.baseNode();

      await expect(znsController.setThisResolver(NON_NULL_ADDRESS))
        .to.emit(znsRegistry, 'NewResolver')
        .withArgs(baseNodeNameHash, NON_NULL_ADDRESS);
    });

    it('should be able to set account name length thresholds when called by owner', async function () {
      assert((await znsController.minAccountNameLengthAllowed()) == 1);

      await expect(await znsController.setAccountNameLengthThreshold(6))
        .to.emit(znsController, 'AccountNameLengthThresholdChanged')
        .withArgs(6);
      assert((await znsController.minAccountNameLengthAllowed()) == 6);

      //register ZNS should fail below the length of 6
      pubX = ethers.utils.hexZeroPad(X_ADDRESS, 32);
      pubY = ethers.utils.hexZeroPad(Y_ADDRESS, 32);
      await expect(
        znsController.registerZNS('karen', NON_NULL_ADDRESS, pubX, pubY, NON_NULL_ADDRESS),
      ).to.be.revertedWith('invalid name');
    });

    it('should be able to register a new account name through a assigned controller', async function () {
      await expect(znsController.connect(addr1).registerZNS('chan', addr1.getAddress(), pubX, pubY, NULL_ADDRESS)).to.be
        .reverted;

      znsController.addController(addr1.getAddress());
      await expect(znsController.connect(addr1).registerZNS('chan', addr1.getAddress(), pubX, pubY, NULL_ADDRESS)).to
        .not.be.reverted;
    });

    it('should not allow same name to be registered twice', async function () {
      znsController.addController(addr1.getAddress());
      await expect(znsController.connect(addr1).registerZNS('chan', addr1.getAddress(), pubX, pubY, NULL_ADDRESS)).to
        .not.be.reverted;

      await expect(
        znsController.connect(addr1).registerZNS('chan', addr1.getAddress(), pubX, pubY, NULL_ADDRESS),
      ).to.be.revertedWith('pub key existed');
    });

    it('should allow withdrawing collected contract funds when called by owner', async function () {
      //Send money to the contract first by registering a name
      priceOracle.price.returns(ethers.utils.parseEther('1'));
      await znsController.addController(addr1.getAddress());
      await znsController
        .connect(addr1)
        .registerZNS('chan', addr1.getAddress(), pubX, pubY, NULL_ADDRESS, { value: ethers.utils.parseEther('10') }); //Send a lot

      //Should be able to precisely withdraw all the funds
      const wallet = ethers.Wallet.createRandom();
      await expect(znsController.withdraw(await wallet.getAddress(), ethers.utils.parseEther('1')))
        .to.emit(znsController, 'Withdraw')
        .withArgs(await wallet.getAddress(), ethers.utils.parseEther('1'));

      const balanceAfter = await ethers.provider.getBalance(await wallet.getAddress());
      expect(balanceAfter).to.equal(ethers.utils.parseEther('1'));
    });
  });
});
