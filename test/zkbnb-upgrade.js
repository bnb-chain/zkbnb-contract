const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('ZkBNB-Legend contract', function () {
  const provider = new ethers.providers.JsonRpcProvider();

  let ZkBNB, zkbnb;
  let ZkBNB2, zkbnb2;
  let Bank, bank;
  let DeployFactory, factory;
  let owner, addr1, addr2, addrs;
  let zkbnbProxy, bankProxy, gatekeeper;

  const abi1 = require('../artifacts/contracts/test-contracts/ZkBNBUpgradeTest.sol/ZkBNBUpgradeTest.json').abi;
  const abi2 = require('../artifacts/contracts/test-contracts/UpgradableBank.sol/UpgradableBank.json').abi;
  const abi3 = require('../artifacts/contracts/UpgradeGatekeeper.sol/UpgradeGatekeeper.json').abi;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // deploy zkbnb
    ZkBNB = await ethers.getContractFactory('ZkBNBUpgradeTest');
    zkbnb = await ZkBNB.deploy();
    await zkbnb.deployed();

    Bank = await ethers.getContractFactory('UpgradableBank');
    bank = await Bank.deploy();
    await bank.deployed();

    // init deploy factory
    DeployFactory = await ethers.getContractFactory('DeployFactoryTest');
    factory = await DeployFactory.connect(owner).deploy(zkbnb.address, bank.address);

    // get deployed proxy contract and the gatekeeper contract
    const tx = await factory.deployTransaction;
    const receipt = await tx.wait();
    const AddressesInterface = new ethers.utils.Interface([
      'event Addresses(address zkbnb, address bank, address gatekeeper)',
    ]);
    // The event 2 is the required event.
    const event = AddressesInterface.decodeEventLog('Addresses', receipt.logs[2].data, receipt.logs[2].topics);
    // get inner contract address
    zkbnbProxy = new ethers.Contract(event[0], abi1, provider);
    bankProxy = new ethers.Contract(event[1], abi2, provider);
    gatekeeper = new ethers.Contract(event[2], abi3, provider);
  });

  describe('ZkBNB Upgrade Test', function () {
    it('test normal upgrade', async function () {
      // before upgrade: balance = 0
      const tx1 = await zkbnbProxy.connect(addr1).setBalance(5);
      await tx1.wait();
      const tx2 = await zkbnbProxy.connect(addr1).setBalance(5);
      await tx2.wait();
      // expect balance = 10
      expect(await zkbnbProxy.connect(addr1).balance()).to.equal(10);

      const tx3 = await bankProxy.connect(addr1).setBankBalance(5);
      await tx3.wait();
      const tx4 = await bankProxy.connect(addr1).setBankBalance(5);
      await tx4.wait();
      expect(await bankProxy.connect(addr1).bankBalance()).to.equal(10);

      // deploy new zkbnb contract
      ZkBNB2 = await ethers.getContractFactory('ZkBNBUpgradeTargetTest');
      zkbnb2 = await ZkBNB2.deploy();
      await zkbnb2.deployed();

      // --- main upgrade workflow ---
      // start upgrade
      const newTarget = [zkbnb2.address, ethers.constants.AddressZero];
      const tx5 = await gatekeeper.connect(owner).startUpgrade(newTarget);
      await tx5.wait();

      // start preparation
      const tx6 = await gatekeeper.connect(owner).startPreparation();
      await tx6.wait();

      // finish upgrade
      const tx7 = await gatekeeper.connect(owner).finishUpgrade([[], []]);
      await tx7.wait();

      // check remained storage
      // expect balance = 22 = 10 + 12(in upgrade callback function)
      expect(await zkbnbProxy.connect(addr1).balance()).to.equal(22);

      // after upgrade
      const tx8 = await zkbnbProxy.connect(addr1).setBalance(10);
      await tx1.wait();
      // expect balance = 72 = 22 + 10 * 5
      expect(await zkbnbProxy.connect(addr1).balance()).to.equal(72);
    });
  });
});
