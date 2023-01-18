import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { getKeccak256, getPublicKey, getSeed } from '../util';
import { assert, expect } from 'chai';
import { ethers } from 'hardhat';
import {smock} from "@defi-wonderland/smock";
import {hexToBytes, hexToNumber} from "web3-utils";
import {formatBytes32String} from "ethers/lib/utils";
import {BytesLike} from "ethers";
import {NULL_ADDRESS} from "../constants";

/**
 * All use cases related to ZKBNB.sol for registering account names
 */
describe('ZKBNB', function () {
    let zkbnb;
    let znsController;
    let mockZNSController;
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
        const mockGovernance = await smock.fake('Governance');
        const mockZkBNBVerifier = await smock.fake('ZkBNBVerifier');
        mockZNSController = await smock.fake('ZNSController');
        const mockPublicResolver = await smock.fake('PublicResolver');
        const mockAdditionalZkBNB = await smock.fake('AdditionalZkBNB');
        const mockERC20 = await smock.fake('ERC20');
        const mockERC721 = await smock.fake('ERC721');


        const Utils = await ethers.getContractFactory('Utils');
        const utils = await Utils.deploy();
        await utils.deployed();

        const ZkBNB = await ethers.getContractFactory('ZkBNBTest', {
            libraries: {
                Utils: utils.address,
            },
        });
        zkbnb = await ZkBNB.deploy();
        await zkbnb.deployed();
        //Set min max age intervals for proper testing
        await zkbnb.testSetMinMaxIntervalsForNameRegistration(3 , 6);

        const initParams = ethers.utils.defaultAbiCoder.encode(
            ['address', 'address', 'address', 'address', 'address', 'bytes32'],
            [
                mockGovernance.address,
                mockZkBNBVerifier.address,
                mockAdditionalZkBNB.address,
                mockZNSController.address,
                mockPublicResolver.address,
                '0x0000000000000000000000000000000000000000000000000000000000000000',
            ],
        );
        await zkbnb.initialize(initParams);
    });

    it('should provide a way to create a commitment hash for a account name', async function () {
        const secretHashFromString = getKeccak256("My secret seed string");
        const commitment: string = await zkbnb.makeCommitment("sri.zkbnb", owner.getAddress(), secretHashFromString);
        assert(commitment.length != 0)
    });

    it('should be able to accept a commitment hash for the first time', async function () {
        //1. Create a hash
        const secretHashFromString = getKeccak256("My secret seed string");
        const commitment: string = await zkbnb.makeCommitment("sri.zkbnb", owner.getAddress(), secretHashFromString);
        assert(commitment.length != 0)

        //2. Publish the hash to zkbnb
        await expect(zkbnb.commit(commitment)).to.not.be.reverted
    });

    it('should reject same second hash by a second party before the max interval is elapsed', async function () {
        //Setup
        const secretHashFromString = getKeccak256("My secret seed string");
        const commitment: string = await zkbnb.makeCommitment("sri.zkbnb", owner.getAddress(), secretHashFromString);
        assert(commitment.length != 0)
        await zkbnb.commit(commitment)
        const minAge = hexToNumber(await zkbnb.minCommitmentAge())
        const maxAge = hexToNumber(await zkbnb.maxCommitmentAge())

        //Test the second commitment before the first expires
        // 0 sec wait
        await expect(zkbnb.connect(addr1).commit(commitment)).to.be.revertedWith("ae")
        // minAge wait
        await new Promise(f => setTimeout(f, minAge*1000));
        await expect(zkbnb.connect(addr1).commit(commitment)).to.be.revertedWith("ae")
    });

    it('should be able to replace the same first commitment after max interval is elapsed', async function () {
        //Setup
        const secretHashFromString = getKeccak256("My secret seed string");
        const commitment: string = await zkbnb.makeCommitment("sri.zkbnb", owner.getAddress(), secretHashFromString);
        assert(commitment.length != 0)
        await zkbnb.commit(commitment)
        const minAge = hexToNumber(await zkbnb.minCommitmentAge())
        const maxAge = hexToNumber(await zkbnb.maxCommitmentAge())

        // maxAge wait
        await new Promise(f => setTimeout(f, (maxAge + 1)*1000));
        await expect(zkbnb.connect(addr1).commit(commitment)).to.not.be.reverted
    });


    describe('After a hash is committed by the owner', async function () {
        let secretHashFromString
        let minAge
        let maxAge
        let x
        let y

        beforeEach('create base node first', async function () {
            minAge = hexToNumber(await zkbnb.minCommitmentAge())
            maxAge = hexToNumber(await zkbnb.maxCommitmentAge())
            secretHashFromString = getKeccak256("My secret seed string")

            const commitment: string = await zkbnb.makeCommitment("sri.zkbnb", owner.getAddress(), secretHashFromString)
            await zkbnb.commit(commitment)

            const nodeHashMockReturn: BytesLike = formatBytes32String("Some mock hash")
            const accountNumberMockReturn = 33;
            //Mock should return the nodeHash and the accountHash
            mockZNSController.isRegisteredZNSName.returns(false)
            mockZNSController.registerZNS.returns(
                {
                    subnode: nodeHashMockReturn,
                    accountIndex: accountNumberMockReturn
                })
            x = ethers.utils.hexZeroPad(NULL_ADDRESS, 32)
            y = ethers.utils.hexZeroPad(NULL_ADDRESS, 32)
        });

        it('should fail to register if, wait period < minAge', async function () {

            await expect(zkbnb.registerZNS("sri.zkbnb", owner.getAddress(), secretHashFromString, x, y))
                .to.be.revertedWith("not enough wait")
        });

        it('should register successfully if, minAge < wait period < maxAge', async function () {
            await new Promise(f => setTimeout(f, (minAge + 1)*1000));

            await expect(zkbnb.registerZNS("sri.zkbnb", owner.getAddress(), secretHashFromString, x, y))
                .to.not.be.reverted
        });

        it('should fail to register if the commitment expired ie wait period > maxAge', async function () {
            await new Promise(f => setTimeout(f, (maxAge + 1)*1000));

            await expect(zkbnb.registerZNS("sri.zkbnb", owner.getAddress(), secretHashFromString, x, y))
                .to.be.revertedWith("too old")
        });

        it('should reject if already registered', async function () {
            mockZNSController.isRegisteredZNSName.returns(true)
            //Wait min time
            await new Promise(f => setTimeout(f, (minAge + 1)*1000));
            await expect(zkbnb.registerZNS("sri.zkbnb", owner.getAddress(), secretHashFromString, x, y))
                .to.be.revertedWith("already exists")
        });
    });

    it('should reject registration without prior commitment', async function () {
        //Setup
        const secretHashFromString = getKeccak256("My secret seed string");
        const x = ethers.utils.hexZeroPad(NULL_ADDRESS, 32)
        const y = ethers.utils.hexZeroPad(NULL_ADDRESS, 32)

        await expect(zkbnb.registerZNS("sri.zkbnb", owner.getAddress(), secretHashFromString, x, y))
                .to.be.revertedWith("too old")
    });
});
