import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { getKeccak256 } from '../util';
import { assert, expect } from 'chai';
import { ethers } from 'hardhat';
import { NON_NULL_ADDRESS, NULL_ADDRESS } from '../constants';
/* eslint-disable */
const namehash = require('eth-ens-namehash');

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
    const [nodeCreated] = event.args;

    expect(await zns.recordExists(nodeCreated)).to.equal(true);
    expect(await zns.owner(nodeCreated)).to.equal(ZNSControllerAddress);
  });

  it('should not replace an existing TLD node by anyone', async function () {
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
    const [nodeCreated] = event.args;
    expect(await zns.recordExists(nodeCreated)).to.equal(true);
    expect(await zns.owner(nodeCreated)).to.equal(ZNSControllerAddress);

    //Replace with a new controller address for existing base node
    const ZNSControllerAddress2 = await addr2.getAddress();
    await expect(
      zns.setSubnodeOwner(
        rootNode,
        baseNodeLabel,
        ZNSControllerAddress2,
        ethers.constants.HashZero,
        ethers.constants.HashZero,
      ),
    ).to.be.revertedWith('sub node exists');
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
      const event2 = rc.events.find((event) => event.event === 'NewResolver');
      const [nodeCreated] = event1.args;

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
      const [nodeCreated] = event1.args;
      const [nodeCreatedDuplicate, newResolver] = event2.args;

      assert(nodeCreated === nodeCreatedDuplicate);
      assert(newResolver === resolverContractAddress);
      expect(await zns.recordExists(nodeCreated)).to.equal(true);
      expect(await zns.owner(nodeCreated)).to.equal(newAccountL1Address);
    });

    it('should be able to overwrite only the resolver address for the same account name', async function () {
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
      const event = rc.events.find((event) => event.event === 'NewOwner');
      const [nodeCreated] = event.args;

      expect(await zns.subNodeRecordExists(baseNode, accountNode)).to.equal(true);

      //Idempotency. Trying to set all records again fails
      await expect(
        zns.setSubnodeOwner(
          baseNode,
          accountNode,
          newAccounAlternatetL1Address,
          ethers.constants.HashZero,
          ethers.constants.HashZero,
        ),
      ).to.be.revertedWith('sub node exists');

      //Set resolver succeeds
      await expect(zns.setResolver(nodeCreated, resolverContractAddress)).to.be.revertedWith('unauthorized');
      await expect(zns.connect(addr1).setResolver(nodeCreated, resolverContractAddress)).to.not.be.reverted;
    });

    it('Each account name must have unique account Index', async function () {
      const accountNode = getKeccak256('xiaoming');
      const accountNode2 = getKeccak256('minyan');

      const newAccountL1Address = await addr1.getAddress();
      const newAccountL2Address = await addr1.getAddress();

      const tx = await zns.setSubnodeRecord(
        baseNode,
        accountNode,
        newAccountL1Address,
        ethers.constants.HashZero,
        ethers.constants.HashZero,
        NULL_ADDRESS,
      );
      const rc = await tx.wait();
      const event = rc.events.find((event) => event.event === 'NewOwner');
      const [nodeCreated] = event.args;

      const tx2 = await zns.setSubnodeRecord(
        baseNode,
        accountNode2,
        newAccountL2Address,
        ethers.constants.HashZero,
        ethers.constants.HashZero,
        NULL_ADDRESS,
      );
      const rc2 = await tx2.wait();
      const event2 = rc2.events.find((event) => event.event === 'NewOwner');
      const [nodeCreated2] = event2.args;

      const res = await zns.accountIndex(nodeCreated);
      const res2 = await zns.accountIndex(nodeCreated2);
      assert(res != res2 && res2 == res + 1);
    });

    it('Should disallow a user owning a subnode to set a nested node such as jackie.chan.zkbnb', async function () {
      //Register chan.legend first
      const accountNode = getKeccak256('chan');
      const newAccountL1Address = await addr1.getAddress();
      const tx2 = await zns.setSubnodeRecord(
        baseNode,
        accountNode,
        newAccountL1Address,
        ethers.constants.HashZero,
        ethers.constants.HashZero,
        NULL_ADDRESS,
      );
      const rc2 = await tx2.wait();
      const event1 = rc2.events.find((event) => event.event === 'NewOwner');
      const [subNode] = event1.args;

      const nestedNode = getKeccak256('jackie'); //jackie.chan.bnb
      const changedL1Address = await addr2.getAddress();

      //Use the newly registered user as msg.sender to create a nested domain
      await expect(
        zns
          .connect(addr1)
          .setSubnodeRecord(
            subNode,
            nestedNode,
            changedL1Address,
            ethers.constants.HashZero,
            ethers.constants.HashZero,
            NULL_ADDRESS,
          ),
      ).to.be.revertedWith('node not allowed');
    });
  });
});
