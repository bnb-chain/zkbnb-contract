import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
import {getKeccak256, registerUser} from "../util";
import { assert, expect } from 'chai'
import namehash from 'eth-ens-namehash';
import {Client} from '@bnb-chain/zkbas-js-sdk';
import { ethers } from 'hardhat'

describe('ZNS', function () {
    let zns;
    let zkbnb;
    let owner;
    let addr1;
    let addr2;
    let addr3;

    before("init ZkBNB Client", async function () {
        const client = new Client('http://localhost:8888');
        const res = await client.getBlocks(0, 1);
        console.log(res)
    });

    beforeEach(async function () {
        const signers: SignerWithAddress[] = await ethers.getSigners()
        owner = signers[0]
        addr1 = signers[1]
        addr2 = signers[2]
        addr3 = signers[3]
        let ZNS = await ethers.getContractFactory("ZNSRegistry");
        zns = await ZNS.deploy()
        await zns.deployed()

        // deploy utils
        let Utils = await ethers.getContractFactory("Utils")
        let utils = await Utils.deploy()
        await utils.deployed()

        let ZkBNB = await ethers.getContractFactory('ZkBNB', {
            libraries: {
                Utils: utils.address
            }
        })
        zkbnb = await ZkBNB.deploy();
        await zkbnb.deployed();
    });

    it('should be able to register new node', async function () {
        // register root node
        const rootL2Account = ethers.utils.formatBytes32String('legend');
        const rootNode = namehash.hash('');
        expect(await zns.owner(rootNode)).to.equal(await owner.getAddress());

        const baseNameHash = getKeccak256('legend');
        const baseNode = namehash.hash('legend');

        // register
        await registerUser(owner, zkbnb, 'zkbnb.legend', addr1.getAddress())
        expect(await zns.owner(namehash.hash('zkbnb.legend'))).to.equal(await addr1.getAddress());
    });


    it('should not be able to register illegal node', async function () {
        // // register illegal name
        // const addr2L2Account = ethers.utils.formatBytes32String('zkbnb2.legend');
        // await expect(
        //     zkbnb.connect(owner).register('id', await addr2.getAddress(), addr2L2Account)
        // ).to.be.revertedWith("invalid name");
        // await expect(
        //     zkbnb.connect(owner).register('id-a', await addr2.getAddress(), addr2L2Account)
        // ).to.be.revertedWith("invalid name");
    });


    it('should not be able to register existing node', async function () {
        // await expect(
        //     zkbnb.connect(owner).register('foo', await addr1.getAddress(), addr1L2Account)
        // ).to.be.revertedWith('L2 owner existed');
    });

    });