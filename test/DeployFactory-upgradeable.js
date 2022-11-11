const { expect } = require("chai");
const { ethers } = require("hardhat");
const abi1 = require("../artifacts/contracts/test-contracts/ZkBNBUpgradeTest.sol/ZkBNBUpgradeTest.json").abi;
const abi2 = require("../artifacts/contracts/test-contracts/UpgradableBank.sol/UpgradableBank.json").abi;
const abi3 = require("../artifacts/contracts/UpgradeGatekeeper.sol/UpgradeGatekeeper.json").abi;
const provider = new ethers.providers.JsonRpcProvider();

describe("DeployFactory contract", function () {
  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {

    const [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    const governor = owner.address;

    // Step 1: deploy zns and register root node
    const ZNSRegistryFactory = await ethers.getContractFactory("ZNSRegistry");
    const znsRegistry = await ZNSRegistryFactory.deploy();
    await znsRegistry.deployed();

    // Step 2: deploy proxied contract
    const GovernanceFactory = await ethers.getContractFactory("Governance");
    // governance
    const governance = await GovernanceFactory.deploy();
    await governance.deployed();
    // asset governance
    const AssetGovernanceFactory = await ethers.getContractFactory("AssetGovernance");
    // verifier
    const VerifierFactory = await ethers.getContractFactory("ZkBNBVerifier");
    const verifier = await VerifierFactory.deploy();
    await verifier.deployed();
    // zkbnb with utils
    const UtilsLibrary = await ethers.getContractFactory("Utils");
    const utils = await UtilsLibrary.deploy();
    await utils.deployed();
    const ZkBNBFactory = await ethers.getContractFactory("ZkBNB", {
      libraries: {
        Utils: utils.address,
      },
    });
    const zkbnb = await ZkBNBFactory.deploy();
    await zkbnb.deployed();
    // ZNS controller
    const ZnsControllerFactory = await ethers.getContractFactory("ZNSController");
    const znsController = await ZnsControllerFactory.deploy();
    await znsController.deployed();
    // ZNS resolver
    const PublicResolverFactory = await ethers.getContractFactory("PublicResolver");
    const znsResolver = await PublicResolverFactory.deploy();
    await znsResolver.deployed();
    // ZNS price oracle
    const ZNSPriceOracleFactory = await ethers.getContractFactory("StablePriceOracle");
    const rentPrices = [0, 1, 2];
    const znsPriceOracle = await ZNSPriceOracleFactory.connect(owner).deploy(rentPrices);
    await znsPriceOracle.deployed();

    // Step 3: initialize deploy factory and finish deployment
    const _genesisAccountRoot = "0x01ef55cdf3b9b0d65e6fb6317f79627534d971fd96c811281af618c0028d5e7a";
    const _listingFee = ethers.utils.parseEther("100");
    const _listingCap = 2 ** 16 - 1;
    const baseNode = namehash.hash("legend");
    DeployFactory = await ethers.getContractFactory("DeployFactory");
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
      baseNode
    );
    await deployFactory.deployed();
    // Get deployed proxy contracts and the gatekeeper contract,
    // they are used for invoking methods.
    const deployFactoryTxReceipt = await deployFactory.deployTransaction.wait();
    const AddressesInterface = new ethers.utils.Interface([
      "event Addresses(address governance, address assetGovernance, address verifier, address znsController, address znsResolver, address zkbnb, address gatekeeper)",
    ]);
    // The event 2 is the required event.
    // console.log(deployFactoryTxReceipt.logs)
    let event = AddressesInterface.decodeEventLog("Addresses", deployFactoryTxReceipt.logs[8].data, deployFactoryTxReceipt.logs[8].topics);
    // Get inner contract proxy address
    // console.log(event)
    znsControllerProxy = ZNSControllerContract.attach(event[3]);
    zkbnbProxy = ZkBNB.attach(event[5]);

    // Step 4: register zns base node
    const rootNode = "0x0000000000000000000000000000000000000000000000000000000000000000";
    const baseNodeLabel = "0x281aceaf4771e7fba770453ce3ed74983a7343be68063ea7d50ab05c1b8ef751"; // mimc('legend');
    const setBaseNodeTx = await znsRegistry.connect(owner).setSubnodeOwner(rootNode, baseNodeLabel, znsControllerProxy.address, ethers.constants.HashZero);
    await setBaseNodeTx.wait();
    expect(await znsRegistry.owner(baseNode)).to.equal(await znsControllerProxy.address);
  });

  describe("ZkBNB Upgrade Test", function () {
    it("test normal upgrade", async function () {
      // before upgrade: balance = 0
      let tx1 = await zkbnbProxy.connect(addr1).setBalance(5);
      await tx1.wait();
      let tx2 = await zkbnbProxy.connect(addr1).setBalance(5);
      await tx2.wait();
      // expect balance = 10
      expect(await zkbnbProxy.connect(addr1).balance()).to.equal(10);

      let tx3 = await bankProxy.connect(addr1).setBankBalance(5);
      await tx3.wait();
      let tx4 = await bankProxy.connect(addr1).setBankBalance(5);
      await tx4.wait();
      expect(await bankProxy.connect(addr1).bankBalance()).to.equal(10);

      // deploy new zkbnb contract
      ZkBNB2 = await ethers.getContractFactory("ZkBNBUpgradeTargetTest");
      zkbnb2 = await ZkBNB2.deploy();
      await zkbnb2.deployed();

      // --- main upgrade workflow ---
      // start upgrade
      let newTarget = [zkbnb2.address, ethers.constants.AddressZero];
      let tx5 = await gatekeeper.connect(owner).startUpgrade(newTarget);
      await tx5.wait();

      // start preparation
      let tx6 = await gatekeeper.connect(owner).startPreparation();
      await tx6.wait();

      // finish upgrade
      let tx7 = await gatekeeper.connect(owner).finishUpgrade([[], []]);
      await tx7.wait();

      // check remained storage
      // expect balance = 22 = 10 + 12(in upgrade callback function)
      expect(await zkbnbProxy.connect(addr1).balance()).to.equal(22);

      // after upgrade
      let tx8 = await zkbnbProxy.connect(addr1).setBalance(10);
      await tx1.wait();
      // expect balance = 72 = 22 + 10 * 5
      expect(await zkbnbProxy.connect(addr1).balance()).to.equal(72);
    });

    it("should can cancel upgrade", () => {});
  });
});
