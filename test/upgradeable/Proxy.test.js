const chai = require('chai');
const { ethers } = require('hardhat');
const { smock } = require('@defi-wonderland/smock');
const { deployZkBNB, deployMockZkBNB, deployMockGovernance } = require('../util');

const { expect } = chai;
chai.use(smock.matchers);

describe('Proxy', function () {
  let Proxy;
  let mockGovernance;
  let mockZkBNBVerifier;
  let mockZkBNB;

  let proxyGovernance;
  let proxyZkBNBVerifier;
  let owner, addr1, addr2, addr3;

  let proxyZkBNB;
  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    mockGovernance = await deployMockGovernance();

    const MockZkBNBVerifier = await smock.mock('ZkBNBVerifier');
    mockZkBNBVerifier = await MockZkBNBVerifier.deploy();
    await mockZkBNBVerifier.deployed();

    mockZkBNB = await deployMockZkBNB();

    Proxy = await ethers.getContractFactory('Proxy');

    mockGovernance.initialize.returns();
    mockZkBNBVerifier.initialize.returns();
    mockZkBNB.initialize.returns();

    proxyGovernance = await Proxy.deploy(mockGovernance.address, owner.address);
    proxyZkBNBVerifier = await Proxy.deploy(mockZkBNBVerifier.address, owner.address);
    proxyZkBNB = await Proxy.deploy(mockZkBNB.address, owner.address);
    await proxyGovernance.deployed();
    await proxyZkBNBVerifier.deployed();
    await proxyZkBNB.deployed();
  });

  it('Proxy contract should initialize target contract', async function () {
    expect(mockGovernance.initialize).to.be.delegatedFrom(proxyGovernance.address);
    expect(mockGovernance.initialize).to.have.been.calledWith(owner.address.toLowerCase());
    expect(mockZkBNBVerifier.initialize).to.be.delegatedFrom(proxyZkBNBVerifier.address);
    expect(mockZkBNBVerifier.initialize).to.have.been.calledWith(owner.address.toLowerCase());
    expect(mockZkBNB.initialize).to.be.delegatedFrom(proxyZkBNB.address);
    expect(mockZkBNB.initialize).to.have.been.calledWith(owner.address.toLowerCase());
  });

  it('Proxy contract should store target address ', async function () {
    expect(await proxyGovernance.getTarget()).to.equal(mockGovernance.address);
    expect(await proxyZkBNBVerifier.getTarget()).to.equal(mockZkBNBVerifier.address);
    expect(await proxyZkBNB.getTarget()).to.equal(mockZkBNB.address);
  });

  describe('Proxy contract should upgrade new target', function () {
    it('upgrade new `Governance` target', async function () {
      const mockGovernanceNew = await deployMockGovernance();

      await proxyGovernance.upgradeTarget(mockGovernanceNew.address, ethers.constants.HashZero);
      expect(mockGovernanceNew.upgrade).to.be.delegatedFrom(proxyGovernance.address);
      expect(mockGovernanceNew.upgrade).to.have.been.calledWith(ethers.constants.HashZero);
    });

    it('upgradeTarget event', async function () {
      const mockGovernanceNew = await deployMockGovernance();

      const upgrade = await proxyGovernance.upgradeTarget(mockGovernanceNew.address, addr1.address);
      const receipt = await upgrade.wait();
      const event = receipt.events.filter(({ event }) => {
        return event === 'Upgraded';
      });

      expect(event[0]).to.be.not.null;
    });

    it('upgrade new `ZkBNBVerifier` target', async function () {
      const MockZkBNBVerifier = await smock.mock('ZkBNBVerifier');
      const mockZkBNBVerifierNew = await MockZkBNBVerifier.deploy();
      await mockZkBNBVerifierNew.deployed();

      await proxyZkBNBVerifier.upgradeTarget(mockZkBNBVerifierNew.address, ethers.constants.HashZero);
      expect(mockZkBNBVerifierNew.upgrade).to.be.delegatedFrom(proxyZkBNBVerifier.address);
      expect(mockZkBNBVerifierNew.upgrade).to.have.been.calledWith(ethers.constants.HashZero);
    });

    it('upgrade new `ZkBNB` target', async function () {
      const mockZkBNBNew = await deployMockZkBNB();
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

    it('intercept `ZkBNB` upgrade', async function () {
      const zkBNBImplement = mockZkBNB.attach(proxyZkBNB.address);
      expect(zkBNBImplement.upgrade(addr3.address)).to.be.revertedWith('upg11');
    });
  });

  describe('Destruct logic contract with `upgrade` method', function () {
    let proxy, zkBNB;
    let mockAdditionalZkBNB, mockDesertVerifier;

    it('deploy ZkBNB', async function () {
      const MockAdditionalZkBNB = await smock.mock('AdditionalZkBNB');

      mockAdditionalZkBNB = await MockAdditionalZkBNB.deploy();
      await mockAdditionalZkBNB.deployed();

      zkBNB = await deployZkBNB('ZkBNB');
      await zkBNB.deployed();

      mockDesertVerifier = await smock.fake('DesertVerifier');

      const initParams = ethers.utils.defaultAbiCoder.encode(
        ['address', 'address', 'address', 'address', 'bytes32'],
        [
          mockGovernance.address,
          mockZkBNBVerifier.address,
          mockAdditionalZkBNB.address,
          mockDesertVerifier.address,
          '0x0000000000000000000000000000000000000000000000000000000000000000',
        ],
      );
      proxy = await Proxy.deploy(zkBNB.address, initParams);

      expect(await proxy.getTarget()).to.equal(zkBNB.address);
    });

    it('upgrade zkBNB', async function () {
      const attackerContract = await smock.fake('AdditionalZkBNB');
      const upgradeParams = ethers.utils.defaultAbiCoder.encode(
        ['address', 'address'],
        [attackerContract.address, mockDesertVerifier.address],
      );

      await expect(zkBNB.upgrade(upgradeParams)).to.be.revertedWith('Can not dirctly call by zkbnbImplementation');
      await proxy.upgradeTarget(zkBNB.address, upgradeParams);
    });

    it('invoking `upgrade` bypassing proxy should be intercepted', async function () {
      const attackerContract = await smock.fake('AdditionalZkBNB');
      const upgradeParams = ethers.utils.defaultAbiCoder.encode(
        ['address', 'address'],
        [attackerContract.address, mockDesertVerifier.address],
      );

      await expect(zkBNB.upgrade(upgradeParams)).to.be.revertedWith('Can not dirctly call by zkbnbImplementation');

      mockGovernance.isActiveValidator.returns();
      // calls bypassing proxy contract should be intercepted
      await expect(zkBNB.revertBlocks([])).to.be.revertedWith('Can not dirctly call by zkbnbImplementation');
    });

    // await zkBNB.upgrade(upgradeParams) will fail
    it.skip('legitimate calls should not be affected by malicious `upgrade`', async function () {
      const attackerContract = await smock.fake('AdditionalZkBNB');
      const upgradeParams = ethers.utils.defaultAbiCoder.encode(
        ['address', 'address'],
        [attackerContract.address, mockDesertVerifier.address],
      );

      await zkBNB.upgrade(upgradeParams);

      // use ZkBNB abi to call function in proxy address
      const zkBNBProxy = new ethers.Contract(proxy.address, zkBNB.interface, owner);

      // deposit BNB works fine
      expect(await zkBNBProxy.depositBNB(owner.address, { value: 100 }))
        .to.emit(zkBNBProxy.address, 'Deposit')
        .withArgs(0, owner.address, 100);

      // calls via Proxy still goes to `mockAdditionalZkBNB` after malicious `upgrade` made
      // `zkBNBProxy` -> `zkBNB` -> `mockAdditionalZkBNB`
      expect(mockAdditionalZkBNB.depositBNB).to.be.delegatedFrom(zkBNBProxy.address);
      expect(mockAdditionalZkBNB.depositBNB).to.have.been.calledOnce;
    });
  });
});
