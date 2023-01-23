const chai = require('chai');
const { ethers } = require('hardhat');
const { smock } = require('@defi-wonderland/smock');

const { expect } = chai;
chai.use(smock.matchers);
const abi = ethers.utils.defaultAbiCoder;

describe('Proxy', function () {
  let mockGovernance;
  let mockZkBNBVerifier;
  let mockZNSController;
  let mockPublicResolver;
  let mockZkBNB;

  // `ZkBNB` needs to link to library `Utils` before deployed
  let utils;

  let proxyGovernance;
  let proxyZkBNBVerifier;
  let owner, addr1, addr2, addr3, addr4;

  let proxyZNSController;
  let proxyPublicResolver;
  let proxyZkBNB;
  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();
    const MockGovernance = await smock.mock('Governance');
    mockGovernance = await MockGovernance.deploy();
    await mockGovernance.deployed();

    const MockZkBNBVerifier = await smock.mock('ZkBNBVerifier');
    mockZkBNBVerifier = await MockZkBNBVerifier.deploy();
    await mockZkBNBVerifier.deployed();

    const MockZNSController = await smock.mock('ZNSController');
    mockZNSController = await MockZNSController.deploy();
    await mockZNSController.deployed();

    const MockPublicResolver = await smock.mock('PublicResolver');
    mockPublicResolver = await MockPublicResolver.deploy();
    await mockPublicResolver.deployed();

    const Utils = await ethers.getContractFactory('Utils');
    utils = await Utils.deploy();
    await utils.deployed();
    const MockZkBNB = await smock.mock('ZkBNB', {
      libraries: {
        Utils: utils.address,
      },
    });
    mockZkBNB = await MockZkBNB.deploy();
    await mockZkBNB.deployed();

    const Proxy = await ethers.getContractFactory('Proxy');

    mockGovernance.initialize.returns();
    mockZkBNBVerifier.initialize.returns();
    mockZNSController.initialize.returns();
    mockPublicResolver.initialize.returns();
    mockZkBNB.initialize.returns();

    proxyGovernance = await Proxy.deploy(mockGovernance.address, owner.address);
    proxyZkBNBVerifier = await Proxy.deploy(mockZkBNBVerifier.address, owner.address);
    proxyZNSController = await Proxy.deploy(mockZNSController.address, owner.address);
    proxyPublicResolver = await Proxy.deploy(mockPublicResolver.address, owner.address);
    proxyZkBNB = await Proxy.deploy(mockZkBNB.address, owner.address);
    await proxyGovernance.deployed();
    await proxyZkBNBVerifier.deployed();
    await proxyZNSController.deployed();
    await proxyPublicResolver.deployed();
    await proxyZkBNB.deployed();
  });

  it('Proxy contract should initialize target contract', async function () {
    expect(mockGovernance.initialize).to.be.delegatedFrom(proxyGovernance.address);
    expect(mockGovernance.initialize).to.have.been.calledWith(owner.address.toLowerCase());
    expect(mockZkBNBVerifier.initialize).to.be.delegatedFrom(proxyZkBNBVerifier.address);
    expect(mockZkBNBVerifier.initialize).to.have.been.calledWith(owner.address.toLowerCase());
    expect(mockZNSController.initialize).to.be.delegatedFrom(proxyZNSController.address);
    expect(mockZNSController.initialize).to.have.been.calledWith(owner.address.toLowerCase());
    expect(mockPublicResolver.initialize).to.be.delegatedFrom(proxyPublicResolver.address);
    expect(mockPublicResolver.initialize).to.have.been.calledWith(owner.address.toLowerCase());
    expect(mockZkBNB.initialize).to.be.delegatedFrom(proxyZkBNB.address);
    expect(mockZkBNB.initialize).to.have.been.calledWith(owner.address.toLowerCase());
  });

  it('Proxy contract should store target address ', async function () {
    expect(await proxyGovernance.getTarget()).to.equal(mockGovernance.address);
    expect(await proxyZkBNBVerifier.getTarget()).to.equal(mockZkBNBVerifier.address);
    expect(await proxyZNSController.getTarget()).to.equal(mockZNSController.address);
    expect(await proxyPublicResolver.getTarget()).to.equal(mockPublicResolver.address);
    expect(await proxyZkBNB.getTarget()).to.equal(mockZkBNB.address);
  });

  describe('Proxy contract should upgrade new target', function () {
    it('upgrade new `Governance` target', async function () {
      const MockGovernance = await smock.mock('Governance');
      const mockGovernanceNew = await MockGovernance.deploy();
      await mockGovernanceNew.deployed();

      await proxyGovernance.upgradeTarget(mockGovernanceNew.address, addr1.address);

      expect(mockGovernanceNew.upgrade).to.be.delegatedFrom(proxyGovernance.address);
      expect(mockGovernanceNew.upgrade).to.have.been.calledWith(addr1.address.toLowerCase());
    });

    it('upgrade new `ZkBNBVerifier` target', async function () {
      const MockZkBNBVerifier = await smock.mock('ZkBNBVerifier');
      const mockZkBNBVerifierNew = await MockZkBNBVerifier.deploy();
      await mockZkBNBVerifierNew.deployed();

      await proxyZkBNBVerifier.upgradeTarget(mockZkBNBVerifierNew.address, ethers.constants.HashZero);
      expect(mockZkBNBVerifierNew.upgrade).to.be.delegatedFrom(proxyZkBNBVerifier.address);
      expect(mockZkBNBVerifierNew.upgrade).to.have.been.calledWith(ethers.constants.HashZero);
    });

    it('upgrade new `ZNSController` target', async function () {
      const MockZNSController = await smock.mock('ZNSController');
      const mockZNSControllerNew = await MockZNSController.deploy();
      await mockZNSControllerNew.deployed();

      const parameters = abi.encode(
        ['address', 'address', 'bytes32'],
        [addr2.address, addr3.address, ethers.utils.hexZeroPad(ethers.utils.hexlify(1), 32)],
      );

      await proxyZNSController.upgradeTarget(mockZNSControllerNew.address, parameters);
      expect(mockZNSControllerNew.upgrade).to.be.delegatedFrom(proxyZNSController.address);
      expect(mockZNSControllerNew.upgrade).to.have.been.calledWith(parameters);
    });

    it('upgrade new `PublicResolver` target', async function () {
      const MockPublicResolver = await smock.mock('PublicResolver');
      const mockPublicResolverNew = await MockPublicResolver.deploy();
      await mockPublicResolverNew.deployed();

      await proxyPublicResolver.upgradeTarget(mockPublicResolverNew.address, addr4.address);
      expect(mockPublicResolverNew.upgrade).to.be.delegatedFrom(proxyPublicResolver.address);
      expect(mockPublicResolverNew.upgrade).to.have.been.calledWith(addr4.address.toLowerCase());
    });

    it('upgrade new `ZkBNB` target', async function () {
      const MockZkBNB = await smock.mock('ZkBNB', {
        libraries: {
          Utils: utils.address,
        },
      });
      const mockZkBNBNew = await MockZkBNB.deploy();
      await mockZkBNBNew.deployed();
      mockZkBNBNew.upgrade.returns(true);

      await proxyZkBNB.upgradeTarget(mockZkBNBNew.address, ethers.constants.AddressZero);
      expect(mockZkBNBNew.upgrade).to.be.delegatedFrom(proxyZkBNB.address);
      expect(mockZkBNBNew.upgrade).to.have.been.calledWith(ethers.constants.AddressZero);
    });
  });

  describe('Proxy contract should delegate function', function () {
    it('delegate `changeGovernor` function', async function () {
      mockGovernance.changeGovernor.returns();

      // use Governance abi to call function in proxy address
      const implement = mockGovernance.attach(proxyGovernance.address);
      await implement.changeGovernor(addr1.address);

      expect(mockGovernance.changeGovernor).to.be.calledOnce;
      expect(mockGovernance.changeGovernor).to.have.been.calledWith(addr1.address);
    });

    it('delegate `verifyProof` function', async function () {
      mockZkBNBVerifier.verifyProof.returns(true);

      const implement = mockZkBNBVerifier.attach(proxyZkBNBVerifier.address);
      await implement.verifyProof([], [], 0);

      expect(mockZkBNBVerifier.verifyProof).to.be.calledOnce;
      expect(mockZkBNBVerifier.verifyProof).to.have.been.calledWith([], [], 0);
    });

    it('delegate `registerZNS` function', async function () {
      mockZNSController.registerZNS.returns(0, 0);

      const implement = mockZNSController.attach(proxyZNSController.address);
      await implement.registerZNS(
        'znsName',
        addr1.address,
        ethers.utils.hexZeroPad(ethers.utils.hexlify(1), 32),
        ethers.utils.hexZeroPad(ethers.utils.hexlify(1), 32),
        addr2.address,
      );

      expect(mockZNSController.registerZNS).to.be.calledOnce;
      expect(mockZNSController.registerZNS).to.have.been.calledWith(
        'znsName',
        addr1.address,
        ethers.utils.hexZeroPad(ethers.utils.hexlify(1), 32),
        ethers.utils.hexZeroPad(ethers.utils.hexlify(1), 32),
        addr2.address,
      );
    });

    it('delegate `name` function', async function () {
      mockPublicResolver.name.returns('mockName');
      const implement = mockPublicResolver.attach(proxyPublicResolver.address);
      const _mockNode = ethers.utils.hexZeroPad(ethers.utils.hexlify(1), 32);
      await implement.name(_mockNode);

      expect(mockPublicResolver.name).to.be.calledOnce;
      expect(mockPublicResolver.name).to.have.been.calledWith(_mockNode);
    });

    it('delegate `commitBlocks` function', async function () {
      mockZkBNB.commitBlocks.returns();
      const blockInfo = {
        blockSize: 1,
        blockNumber: 2,
        priorityOperations: 3,
        pendingOnchainOperationsHash: ethers.utils.hexZeroPad(ethers.utils.hexlify(0), 32),
        timestamp: 4,
        stateRoot: ethers.utils.hexZeroPad(ethers.utils.hexlify(123), 32),
        commitment: ethers.utils.hexZeroPad(ethers.utils.hexlify(1), 32),
      };
      const implement = mockZkBNB.attach(proxyZkBNB.address);
      await implement.commitBlocks(blockInfo, []);

      expect(mockZkBNB.commitBlocks).to.be.calledOnce;
      // TODO: make the assertion pass
      // expect(mockZkBNB.commitBlocks).to.have.been.calledWithExactly(
      //   JSON.parse(JSON.stringify(blockInfo)),
      //   [],
      // );
    });
  });

  describe('Proxy contract should intercept upgrade function', function () {
    it('intercept `Governance` upgrade', async function () {
      const governanceImplement = mockGovernance.attach(proxyGovernance.address);
      expect(governanceImplement.upgrade(addr1.address)).to.be.revertedWith('upg11');
    });

    it('intercept `ZkBNBVerifier` upgrade', async function () {
      const zkBNBVerifierImplement = mockZkBNBVerifier.attach(proxyZkBNBVerifier.address);
      expect(zkBNBVerifierImplement.upgrade(addr2.address)).to.be.revertedWith('upg11');
    });

    it('intercept `ZNSController` upgrade', async function () {
      const zNSControllerImplement = mockZNSController.attach(proxyZNSController.address);
      expect(zNSControllerImplement.upgrade(addr2.address)).to.be.revertedWith('upg11');
    });

    it('intercept `PublicResolver` upgrade', async function () {
      const publicResolverImplement = mockPublicResolver.attach(proxyPublicResolver.address);
      expect(publicResolverImplement.upgrade(addr3.address)).to.be.revertedWith('upg11');
    });

    it('intercept `ZkBNB` upgrade', async function () {
      const zkBNBImplement = mockZkBNB.attach(proxyZkBNB.address);
      expect(zkBNBImplement.upgrade(addr4.address)).to.be.revertedWith('upg11');
    });
  });
});
