import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { getKeccak256, getPublicKey, getSeed } from '../util';
import { assert, expect } from 'chai';
import namehash from 'eth-ens-namehash';
import { ethers } from 'hardhat';
import { NON_NULL_ADDRESS, NULL_ADDRESS } from '../constants';

describe('ZNS', function () {
  let zns;
  let owner;
  let addr1;
  let addr2;
  let addr3;

  beforeEach(async function () {
    const signers: SignerWithAddress[] = await ethers.getSigners();
    owner = signers[0];
    addr1 = signers[1];
    addr2 = signers[2];
    addr3 = signers[3];
    const ZNS = await ethers.getContractFactory('ZNSRegistry');
    zns = await ZNS.deploy();
    await zns.deployed();
  });

  it('should own the blank root node', async function () {
    const rootNode = namehash.hash('');
    expect(await zns.owner(rootNode)).to.equal(await owner.getAddress());
  });

  it('should be able to create a sub node and give control to a ZNSController', async function () {
    const rootNode = namehash.hash('');
    const baseNodeLabel = getKeccak256('legend');

    //Here "ZNSControllerAddress" is a sample controller contract address for the owner of this domain name 'legend'
    const ZNSControllerAddress = await addr1.getAddress();
    const tx = await zns.setSubnodeOwner(
      rootNode,
      baseNodeLabel,
      ZNSControllerAddress,
      ethers.constants.HashZero,
      ethers.constants.HashZero,
    );
    const rc = await tx.wait();
    const event = rc.events.find((event) => event.event === 'NewOwner');
    const [nodeCreated, newOwner] = event.args;

    expect(await zns.recordExists(nodeCreated)).to.equal(true);
    expect(await zns.owner(nodeCreated)).to.equal(ZNSControllerAddress);
  });

  it('should be able to replace an existing sub node if called by the owner of parent node', async function () {
    const rootNode = namehash.hash('');
    const baseNodeLabel = getKeccak256('legend');
    //Here "ZNSControllerAddress" is a sample controller contract address for the owner of this domain name 'legend'
    const ZNSControllerAddress = await addr1.getAddress();
    const tx = await zns.setSubnodeOwner(
      rootNode,
      baseNodeLabel,
      ZNSControllerAddress,
      ethers.constants.HashZero,
      ethers.constants.HashZero,
    );
    const rc = await tx.wait();
    const event = rc.events.find((event) => event.event === 'NewOwner');
    const [nodeCreated, newOwner] = event.args;
    expect(await zns.recordExists(nodeCreated)).to.equal(true);
    expect(await zns.owner(nodeCreated)).to.equal(ZNSControllerAddress);

    //Replace with a new controller address for existing base node
    const ZNSControllerAddress2 = await addr2.getAddress();
    const tx2 = await zns.setSubnodeOwner(
      rootNode,
      baseNodeLabel,
      ZNSControllerAddress2,
      ethers.constants.HashZero,
      ethers.constants.HashZero,
    );
    const rc2 = await tx2.wait();
    const event2 = rc2.events.find((event) => event.event === 'NewOwner');
    const [nodeCreated2, newOwner2] = event.args;
    expect(await zns.recordExists(nodeCreated2)).to.equal(true);
    expect(await zns.owner(nodeCreated2)).to.equal(ZNSControllerAddress2);
  });

  describe('After creating a base node', async function () {
    let baseNode;
    beforeEach('create base node first', async function () {
      const rootNode = namehash.hash('');
      const baseNodeLabel = getKeccak256('legend');
      //Here "ZNSControllerAddress" is a sample controller contract address for the owner of this domain name 'legend'
      const ZNSControllerAddress = await owner.getAddress();
      const tx = await zns.setSubnodeOwner(
        rootNode,
        baseNodeLabel,
        ZNSControllerAddress,
        ethers.constants.HashZero,
        ethers.constants.HashZero,
      );
      const rc = await tx.wait();
      const event = rc.events.find((event) => event.event === 'NewOwner');
      [baseNode] = event.args;
    });

    it('should be able to create a new account name with no resolver', async function () {
      // register new account name
      const accountNode = getKeccak256('xiaoming');

      const newAccountL1Address = await addr1.getAddress();
      const resolverContractAddress = NULL_ADDRESS; //NULL_ADDRESS means no resolver contract
      const tx = await zns.setSubnodeRecord(
        baseNode,
        accountNode,
        newAccountL1Address,
        ethers.constants.HashZero,
        ethers.constants.HashZero,
        resolverContractAddress,
      );
      const rc = await tx.wait();
      const event1 = rc.events.find((event) => event.event === 'NewOwner');
      const event2 = rc.events.find((event) => event.event === 'NewResolver');
      const [nodeCreated, newOwner] = event1.args;

      expect(event2 === undefined).to.equal(true); //No resolver event emitted on null address
      expect(await zns.recordExists(nodeCreated)).to.equal(true);
      expect(await zns.owner(nodeCreated)).to.equal(newAccountL1Address);
    });

    it('should be able to create a new account name with a resolver contract address', async function () {
      const accountNode = getKeccak256('xiaoming');

      const newAccountL1Address = await addr1.getAddress();
      const resolverContractAddress = NON_NULL_ADDRESS;
      const tx = await zns.setSubnodeRecord(
        baseNode,
        accountNode,
        newAccountL1Address,
        ethers.constants.HashZero,
        ethers.constants.HashZero,
        resolverContractAddress,
      );
      const rc = await tx.wait();
      const event1 = rc.events.find((event) => event.event === 'NewOwner');
      const event2 = rc.events.find((event) => event.event === 'NewResolver');
      const [nodeCreated, newOwner] = event1.args;
      const [nodeCreatedDuplicate, newResolver] = event2.args;

      assert(nodeCreated === nodeCreatedDuplicate);
      assert(newResolver === resolverContractAddress);
      expect(await zns.recordExists(nodeCreated)).to.equal(true);
      expect(await zns.owner(nodeCreated)).to.equal(newAccountL1Address);
    });

    it('should be able to overwrite L1 and L2 details of the same account name', async function () {
      const accountNode = getKeccak256('xiaoming');

      const newAccountL1Address = await addr1.getAddress();
      const newAccounAlternatetL1Address = await addr2.getAddress();

      const resolverContractAddress = NULL_ADDRESS; //NULL_ADDRESS means no resolver contract
      const tx = await zns.setSubnodeRecord(
        baseNode,
        accountNode,
        newAccountL1Address,
        ethers.constants.HashZero,
        ethers.constants.HashZero,
        resolverContractAddress,
      );
      const rc = await tx.wait();
      expect(await zns.subNodeRecordExists(baseNode, accountNode)).to.equal(true);

      //overwrite L1 address and L2 address
      const seed = await getSeed(addr2);
      const { x, y } = await getPublicKey(seed);
      const tx2 = await zns.setSubnodeRecord(
        baseNode,
        accountNode,
        newAccounAlternatetL1Address,
        x,
        y,
        resolverContractAddress,
      );
      const rc2 = await tx2.wait();
      const event = rc2.events.find((event) => event.event === 'NewOwner');
      const [nodeCreated, newOwner] = event.args;

      expect(await zns.recordExists(nodeCreated)).to.equal(true);
      expect(await zns.owner(nodeCreated)).to.equal(newAccounAlternatetL1Address);
    });

    it('should be able to create multiple account indexes for a same account', async function () {
      const accountNode = getKeccak256('xiaoming');
      const newAccountL1Address = await addr1.getAddress();
      const tx = await zns.setSubnodeRecord(
        baseNode,
        accountNode,
        newAccountL1Address,
        ethers.constants.HashZero,
        ethers.constants.HashZero,
        NULL_ADDRESS,
      );
      const rc = await tx.wait();
      const event1 = rc.events.find((event) => event.event === 'NewOwner');
      const [nodeCreated, newOwner] = event1.args;

      await zns.setSubnodeAccountIndex(nodeCreated);
      await zns.setSubnodeAccountIndex(nodeCreated);
      await zns.setSubnodeAccountIndex(nodeCreated);
      //Care must be taken at controller to ensure this does not happen
    });
  });

  describe('should be able to change any record without permission through setRecord', async function () {
    let baseNode;
    let nodeCreated;
    beforeEach('create base node and account first', async function () {
      const rootNode = namehash.hash('');
      const baseNodeLabel = getKeccak256('legend');
      //Here "ZNSControllerAddress" is a sample controller contract address for the owner of this domain name 'legend'
      const ZNSControllerAddress = await owner.getAddress();
      const tx = await zns.setSubnodeOwner(
        rootNode,
        baseNodeLabel,
        ZNSControllerAddress,
        ethers.constants.HashZero,
        ethers.constants.HashZero,
      );
      const rc = await tx.wait();
      const event = rc.events.find((event) => event.event === 'NewOwner');
      [baseNode] = event.args;

      const accountNode = getKeccak256('xiaoming');
      const newAccountL1Address = await addr1.getAddress();
      const resolverContractAddress = NULL_ADDRESS; //NULL_ADDRESS means no resolver contract
      const tx2 = await zns.setSubnodeRecord(
        baseNode,
        accountNode,
        newAccountL1Address,
        ethers.constants.HashZero,
        ethers.constants.HashZero,
        resolverContractAddress,
      );
      const rc2 = await tx2.wait();
      const event1 = rc2.events.find((event) => event.event === 'NewOwner');
      [nodeCreated] = event1.args;
    });

    it('change any node details', async function () {
      const changedL1Address = await addr2.getAddress();
      const tx = await zns.setRecord(
        nodeCreated,
        changedL1Address,
        ethers.constants.HashZero,
        ethers.constants.HashZero,
        NULL_ADDRESS,
      );
      const rc = await tx.wait();
      const event = rc.events.find((event) => event.event === 'NewOwner');
      const [nodeCreatedNew] = event.args;

      expect(await zns.owner(nodeCreatedNew)).to.equal(changedL1Address);
    });
  });
});
