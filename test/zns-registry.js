const {expect} = require("chai");
const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')

describe("Zkbas Registry Contract", function () {

    let Zkbas, zkbas;
    let ZNS, zns;
    let Utils, utils;
    let owner, addr1, addr2, addrs;

    // `beforeEach` will run before each test, re-deploying the contract every
    // time. It receives a callback, which can be async.
    beforeEach(async function () {
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

        // deploy zkbas
        ZNS = await ethers.getContractFactory("ZNSRegistry");
        zns = await ZNS.deploy()
        await zns.deployed()

        // deploy utils
        Utils = await ethers.getContractFactory("Utils")
        utils = await Utils.deploy()
        await utils.deployed()

        Zkbas = await ethers.getContractFactory('Zkbas', {
            libraries: {
                Utils: utils.address
            }
        })
        zkbas = await Zkbas.deploy();
        await zkbas.deployed();
    });

    // describe('ZNS Registry', function () {
    //     it("register", async function () {
    //         // register root node
    //         const rootL2Acoount = ethers.utils.formatBytes32String('legend');
    //         const rootNode = namehash.hash('');
    //         expect(await zns.owner(rootNode)).to.equal(await owner.getAddress());
    //
    //         const baseNameHash = getKeccak256('legend');
    //         const baseNode = namehash.hash('legend');
    //         // The owner of ZNS should be registrar
    //         const setRootTx = await zns.setSubnodeOwner(rootNode, baseNameHash, zkbas.address, rootL2Acoount);
    //         await setRootTx.wait();
    //         expect(await zns.owner(baseNode)).to.equal(await zkbas.address);
    //
    //         // register
    //         const addr1L2Account = ethers.utils.formatBytes32String('zkbas.legend');
    //         const registerTx = await zkbas.connect(owner).register('zkbas', await addr1.getAddress(), addr1L2Account)
    //         await registerTx.wait()
    //         expect(await zns.owner(namehash.hash('zkbas.legend'))).to.equal(await addr1.getAddress());
    //
    //         // register illegal name
    //         const addr2L2Account = ethers.utils.formatBytes32String('zkbas2.legend');
    //         await expect(
    //             zkbas.connect(owner).register('id', await addr2.getAddress(), addr2L2Account)
    //         ).to.be.revertedWith("invalid name");
    //         await expect(
    //             zkbas.connect(owner).register('id-a', await addr2.getAddress(), addr2L2Account)
    //         ).to.be.revertedWith("invalid name");
    //
    //         // duplicated L2 owner
    //         await expect(
    //             zkbas.connect(owner).register('foo', await addr1.getAddress(), addr1L2Account)
    //         ).to.be.revertedWith('L2 owner existed');
    //     });
    // });

    // get the keccak256 hash of a specified string name
    // eg: getKeccak256('zkbas') = '0x621eacce7c1f02dbf62859801a97d1b2903abc1c3e00e28acfb32cdac01ab36d'
    const getKeccak256 = (name) => {
        return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name))
    }

    // recursively get the keccak256 hash of a specified sub name with its parent node
    // const getNameHash = (name) => {
    //     var node = ''
    //     for (var i = 0; i < 32; i++) {
    //         node += '00'
    //     }
    //
    //     if (name === '') {
    //         return '0x' + '0'.repeat(64)
    //     }
    //
    //     // split the name into 2 parts, if it contains '.', eg 'a.zkbas.legend' is split into 'a' and 'zkbas.legend'
    //     // or we add '' into the second place, eg 'legend' is split into 'legend' and ''
    //     const parts = name.split('.', 2);
    //     if(parts.length === 1) {
    //         parts.push('')
    //     }
    //
    //     const label = parts[0]
    //     const remainder = parts[1]
    //     console.log(label, remainder)
    //     return getKeccak256('0x' + getNameHash(remainder) + getKeccak256(label))
    // }
});