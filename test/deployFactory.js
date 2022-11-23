const { expect } = require('chai');
const { ethers } = require('hardhat');
const namehash = require('eth-ens-namehash');
// const {mimc} = require("mimcjs");

describe('ZkBNB contract', function () {
  let owner, governor, addr1, addr2, addrs;
  let ZNSRegistry, znsRegistry;
  let ZNSController, znsController;
  let ZNSPriceOracle, znsPriceOracle;
  let PublicResolver, znsResolver;
  let ZkBNB, zkbnb;
  let Verifier, verifier;
  let Governance, governance;
  let AssetGovernance, assetGovernance;
  let DeployFactory, deployFactory, deployFactoryTx, deployFactoryTxReceipt;
  let UpgradeGatekeeper, upgradeGatekeeper;
  let Proxy, zkbnbProxy, znsControllerProxy;
  let Utils, utils;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    governor = owner.address;

    // Step 1: deploy zns and register root node
    ZNSRegistry = await ethers.getContractFactory('ZNSRegistry');
    znsRegistry = await ZNSRegistry.deploy();
    await znsRegistry.deployed();

    // Step 2: deploy proxied contract
    // governance
    Governance = await ethers.getContractFactory('Governance');
    governance = await Governance.deploy();
    await governance.deployed();
    // asset governance
    AssetGovernance = await ethers.getContractFactory('AssetGovernance');
    // assetGovernance = await AssetGovernance.deploy()
    // await assetGovernance.deployed()
    // verifier
    Verifier = await ethers.getContractFactory('ZkBNBVerifier');
    verifier = await Verifier.deploy();
    await verifier.deployed();
    // zkbnb with utils
    const Utils = await ethers.getContractFactory('Utils');
    const utils = await Utils.deploy();
    await utils.deployed();
    ZkBNB = await ethers.getContractFactory('ZkBNB', {
      libraries: {
        Utils: utils.address,
      },
    });
    zkbnb = await ZkBNB.deploy();
    await zkbnb.deployed();
    // ZNS controller
    ZNSController = await ethers.getContractFactory('ZNSController');
    znsController = await ZNSController.deploy();
    await znsController.deployed();
    // ZNS resolver
    PublicResolver = await ethers.getContractFactory('PublicResolver');
    znsResolver = await PublicResolver.deploy();
    await znsResolver.deployed();
    // ZNS price oracle
    ZNSPriceOracle = await ethers.getContractFactory('StablePriceOracle');
    const rentPrices = [0, 1, 2];
    znsPriceOracle = await ZNSPriceOracle.connect(owner).deploy(rentPrices);
    await znsPriceOracle.deployed();

    // Step 3: initialize deploy factory and finish deployment
    const _genesisAccountRoot = '0x01ef55cdf3b9b0d65e6fb6317f79627534d971fd96c811281af618c0028d5e7a';
    const _listingFee = ethers.utils.parseEther('100');
    const _listingCap = 2 ** 16 - 1;
    const baseNode = namehash.hash('legend');
    DeployFactory = await ethers.getContractFactory('DeployFactory');
    deployFactory = await DeployFactory.connect(owner).deploy(
      governance.address,
      verifier.address,
      zkbnb.address,
      znsController.address,
      znsResolver.address,
      _genesisAccountRoot,
      verifier.address,
      governor,
      governance.address,
      _listingFee,
      _listingCap,
      znsRegistry.address,
      znsPriceOracle.address,
      baseNode,
    );
    await deployFactory.deployed();
    // Get deployed proxy contracts and the gatekeeper contract,
    // they are used for invoking methods.
    deployFactoryTx = await deployFactory.deployTransaction;
    deployFactoryTxReceipt = await deployFactoryTx.wait();
    const AddressesInterface = new ethers.utils.Interface([
      'event Addresses(address governance, address assetGovernance, address verifier, address znsController, address znsResolver, address zkbnb, address gatekeeper)',
    ]);
    // The event 2 is the required event.
    // console.log(deployFactoryTxReceipt.logs)
    const event = AddressesInterface.decodeEventLog(
      'Addresses',
      deployFactoryTxReceipt.logs[11].data,
      deployFactoryTxReceipt.logs[11].topics,
    );
    // Get inner contract proxy address
    // console.log(event)
    assetGovernance = AssetGovernance.attach(event[1]);
    znsControllerProxy = ZNSController.attach(event[3]);
    zkbnbProxy = ZkBNB.attach(event[5]);

    // Step 4: register zns base node
    const rootNode = '0x0000000000000000000000000000000000000000000000000000000000000000';
    const baseNodeLabel = '0x281aceaf4771e7fba770453ce3ed74983a7343be68063ea7d50ab05c1b8ef751'; // mimc('legend');
    const setBaseNodeTx = await znsRegistry
      .connect(owner)
      .setSubnodeOwner(rootNode, baseNodeLabel, znsControllerProxy.address, ethers.constants.HashZero);
    await setBaseNodeTx.wait();
    expect(await znsRegistry.owner(baseNode)).to.equal(await znsControllerProxy.address);
  });

  describe('ZkBNB Deploy Test', function () {
    it('test ZNS register', async function () {
      // register ZNS
      const sherPubKey = ethers.utils.formatBytes32String('sher.legend');
      const registerZNSTx = await zkbnbProxy.connect(addr1).registerZNS('sher', await addr1.getAddress(), sherPubKey);

      await registerZNSTx.wait();

      const sherNameHash = namehash.hash('sher.legend');
      expect(await zkbnbProxy.connect(owner).getAddressByAccountNameHash(sherNameHash)).to.equal(
        await addr1.getAddress(),
      );
      expect(await znsRegistry.owner(sherNameHash)).to.equal(await addr1.getAddress());

      // check price oracle
      const sherfromzkbnbPubKey = ethers.utils.formatBytes32String('sherfromzkbnb.legend'); // need 1 bnb for fee
      await expect(
        zkbnbProxy.registerZNS('sherfromzkbnb', await addr1.getAddress(), sherfromzkbnbPubKey),
      ).to.be.revertedWith('nev');
    });

    it('test Deposit BNB', async function () {
      // register ZNS
      const sherPubKey = ethers.utils.formatBytes32String('sher.legend');
      const registerZNSTx = await zkbnbProxy.registerZNS('sher', await addr1.getAddress(), sherPubKey);
      await registerZNSTx.wait();

      const sherNameHash = namehash.hash('sher.legend');
      expect(await zkbnbProxy.connect(owner).getAddressByAccountNameHash(sherNameHash)).to.equal(
        await addr1.getAddress(),
      );
      expect(await znsRegistry.owner(sherNameHash)).to.equal(await addr1.getAddress());

      const depositBNBTx = await zkbnbProxy.connect(addr1).depositBNB(sherNameHash, {
        value: ethers.utils.parseEther('1.0'),
      });
      await depositBNBTx.wait();
    });

    it('test Deposit BEP20', async function () {
      // deploy BEP20 token
      const TokenFactory = await ethers.getContractFactory('ZkBNBRelatedERC20');
      const token = await TokenFactory.connect(addr1).deploy(10000, '', '');
      await token.deployed();
      expect(await token.balanceOf(addr1.address)).to.equal(10000);
      // set allowance
      const setAllowanceTx = await token.connect(addr1).approve(zkbnbProxy.address, 10000);
      await setAllowanceTx.wait();
      expect(await token.allowance(addr1.address, zkbnbProxy.address)).to.equal(10000);

      // add asset
      const addAssetTx = await assetGovernance.connect(owner).addAsset(token.address);
      await addAssetTx.wait();

      // register ZNS
      const sherPubKey = ethers.utils.formatBytes32String('sher.legend');
      const registerZNSTx = await zkbnbProxy.registerZNS('sher', await addr1.getAddress(), sherPubKey);
      await registerZNSTx.wait();

      const sherNameHash = namehash.hash('sher.legend');
      expect(await zkbnbProxy.connect(owner).getAddressByAccountNameHash(sherNameHash)).to.equal(
        await addr1.getAddress(),
      );
      expect(await znsRegistry.owner(sherNameHash)).to.equal(await addr1.getAddress());

      const depositBEP20Tx = await zkbnbProxy.connect(addr1).depositBEP20(token.address, 100, sherNameHash);
      await depositBEP20Tx.wait();
      expect(await token.balanceOf(zkbnbProxy.address)).to.equal(100);
    });

    it('test Deposit ERC721', async function () {
      // deploy ERC721
      const ERC721 = await ethers.getContractFactory('ZkBNBRelatedERC721');
      const erc721 = await ERC721.deploy('zkbnb', 'ZEC', '0');
      await erc721.deployed();
      const approveTx = await erc721.approve(zkbnbProxy.address, '0');
      await approveTx.wait();
      expect(await erc721.getApproved('0')).to.equal(zkbnbProxy.address);

      // register ZNS
      const sherPubKey = ethers.utils.formatBytes32String('sher.legend');
      const registerZNSTx = await zkbnbProxy.registerZNS('sher', await addr1.getAddress(), sherPubKey);
      await registerZNSTx.wait();

      // deposit erc721 into contract
      const sherNameHash = namehash.hash('sher.legend');
      const depositNftTx = await zkbnbProxy.depositNft(sherNameHash, erc721.address, '0');
      await depositNftTx.wait();
    });

    it('test RequestFullExit', async function () {
      // register ZNS
      const sherPubKey = ethers.utils.formatBytes32String('sher.legend');
      const registerZNSTx = await zkbnbProxy.registerZNS('sher', await addr1.getAddress(), sherPubKey);
      await registerZNSTx.wait();

      // deploy BEP20 token
      const TokenFactory = await ethers.getContractFactory('ZkBNBRelatedERC20');
      const token = await TokenFactory.connect(addr1).deploy(10000, '', '');
      await token.deployed();
      expect(await token.balanceOf(addr1.address)).to.equal(10000);
      // set allowance
      const setAllowanceTx = await token.connect(addr1).approve(zkbnbProxy.address, 10000);
      await setAllowanceTx.wait();
      expect(await token.allowance(addr1.address, zkbnbProxy.address)).to.equal(10000);

      // add asset
      const addAssetTx = await assetGovernance.connect(owner).addAsset(token.address);
      await addAssetTx.wait();

      // deposit erc721 into contract
      const sherNameHash = namehash.hash('sher.legend');
      const requestFullExitTx = await zkbnbProxy.connect(addr1).requestFullExit(sherNameHash, token.address);
      await requestFullExitTx.wait();
    });

    it('test RequestFullExitNft', async function () {
      // register ZNS
      const sherPubKey = ethers.utils.formatBytes32String('sher.legend');
      const registerZNSTx = await zkbnbProxy.registerZNS('sher', await addr1.getAddress(), sherPubKey);
      await registerZNSTx.wait();

      // deposit erc721 into contract
      const sherNameHash = namehash.hash('sher.legend');
      const requestFullExitTx = await zkbnbProxy
        .connect(addr1)
        .requestFullExitNft(sherNameHash, '0x0000000000000000000000000000000000000000');
      await requestFullExitTx.wait();
    });
  });

  // get the keccak256 hash of a specified string name
  // eg: getKeccak256('zkbnb') = '0x621eacce7c1f02dbf62859801a97d1b2903abc1c3e00e28acfb32cdac01ab36d'
  const getKeccak256 = (name) => {
    return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name));
  };
});
