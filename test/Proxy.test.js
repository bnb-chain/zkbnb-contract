const chai = require('chai');
const { ethers } = require('hardhat');
const { smock } = require('@defi-wonderland/smock');

const { expect } = chai;
chai.use(smock.matchers);

describe('Proxy', function () {
  let mockGovernance;
  let proxy;
  let owner, addr1;
  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();
    const MockGovernance = await smock.mock('Governance');
    mockGovernance = await MockGovernance.deploy();
    await mockGovernance.deployed();

    const Proxy = await ethers.getContractFactory('Proxy');

    mockGovernance.initialize.returns();

    proxy = await Proxy.deploy(mockGovernance.address, owner.address);
    await proxy.deployed();
  });

  it('Proxy contract should initialize target contract', async function () {
    expect(mockGovernance.initialize).to.be.delegatedFrom(proxy.address);
    expect(mockGovernance.initialize).to.have.been.calledWith(
      owner.address.toLowerCase(),
    );
  });
  it('Proxy contract should has target address ', async function () {
    const addr = await proxy.getTarget();
    expect(addr).to.equal(mockGovernance.address);
  });
  it('Proxy contract should upgrade new target ', async function () {
    const MockGovernance = await smock.mock('Governance');
    const mockGovernanceNew = await MockGovernance.deploy();
    await mockGovernanceNew.deployed();

    await proxy.upgradeTarget(mockGovernanceNew.address, addr1.address);

    expect(mockGovernanceNew.upgrade).to.be.delegatedFrom(proxy.address);

    expect(mockGovernanceNew.upgrade).to.have.been.calledWith(
      addr1.address.toLowerCase(),
    );
  });
  it('Proxy contract should delegate function', async function () {
    mockGovernance.changeGovernor.returns();

    // use Governance abi to call function in proxy address
    const implement = mockGovernance.attach(proxy.address);
    await implement.changeGovernor(addr1.address);

    expect(mockGovernance.changeGovernor).to.be.calledOnce;
    expect(mockGovernance.changeGovernor).to.have.been.calledWith(
      addr1.address,
    );
  });
  it('Proxy contract should Intercepts upgrade function', async function () {
    mockGovernance.changeGovernor.returns();

    //  call function use Governance ABI
    const implement = mockGovernance.attach(proxy.address);
    expect(implement.upgrade(addr1.address)).to.be.revertedWith('upg11');
  });
});
