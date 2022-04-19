const {expect} = require("chai");
const {ethers} = require("hardhat");

describe("Zecrey-Legend contract", function () {

    let ZecreyLegend;
    let zecreyLegend;
    let owner, addr1, addr2, addrs;

    // `beforeEach` will run before each test, re-deploying the contract every
    // time. It receives a callback, which can be async.
    beforeEach(async function () {
        // deploy zecrey
        ZecreyLegend = await ethers.getContractFactory("ZecreyLegend");
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners()

        zecreyLegend = await ZecreyLegend.deploy()
    });

    describe('ZNS Registry', function () {
        it("register and register subname", async function () {
            // register
            const ownerL2Account1 = ethers.utils.formatBytes32String('zecrey')
            const registerTx = await zecreyLegend.register('zecrey', await owner.getAddress(), ownerL2Account1);
            await registerTx.wait()
            // keccak256('zecrey') = '0x621eacce7c1f02dbf62859801a97d1b2903abc1c3e00e28acfb32cdac01ab36d'
            expect(await zecreyLegend.getOwner(getNameHash('zecrey'))).to.equal(await owner.getAddress());

            // registerSubName
            const pnd = getNameHash('zecrey') // parent node
            const ownerL2Account2 = ethers.utils.formatBytes32String('test.zecrey')
            const registerSubNameTx = await zecreyLegend.registerSubName('test', pnd, owner.getAddress(), ownerL2Account2)
            await registerSubNameTx.wait()
            expect(await zecreyLegend.getOwner(getNameHash('test.zecrey'))).to.equal(await owner.getAddress());
        });

        it("Should fail if name is not legal", async function () {
            const ownerL2Account1 = ethers.utils.formatBytes32String('zecrey')
            // register with illegal name
            await expect(
                zecreyLegend.register('id', await owner.getAddress(), ownerL2Account1)
            ).to.be.revertedWith("invalid name");
            await expect(
                zecreyLegend.register('id-a', await owner.getAddress(), ownerL2Account1)
            ).to.be.revertedWith("invalid name");
            await expect(
                zecreyLegend.register('Adas', await owner.getAddress(), ownerL2Account1)
            ).to.be.revertedWith("invalid name");
        });

        it("transfer, should fail if not authorized", async function () {
            // register
            const ownerL2Account = ethers.utils.formatBytes32String('zecrey')
            const registerTx = await zecreyLegend.register('zecrey', await owner.getAddress(), ownerL2Account);
            await registerTx.wait()
            expect(await zecreyLegend.getOwner(getNameHash('zecrey'))).to.equal(await owner.getAddress());

            // transfer
            const addr1L2Account = ethers.utils.formatBytes32String('test1')
            const transferTx = await zecreyLegend.connect(owner).transfer(getNameHash('zecrey'), addr1.getAddress(), addr1L2Account)
            await transferTx.wait()
            expect(await zecreyLegend.getOwner(getNameHash('zecrey'))).to.equal(await addr1.getAddress());

            // reTransfer to addr2 will fail
            const addr2L2Account = ethers.utils.formatBytes32String('test2')
            await expect(
                zecreyLegend.connect(owner).transfer(getNameHash('zecrey'), addr2.getAddress(), addr2L2Account)
            ).to.be.revertedWith("unauthorized");
        });

        it("transferL2, should fail if not authorized", async function () {
            // register
            const ownerL2Account = ethers.utils.formatBytes32String('zecrey')
            const registerTx = await zecreyLegend.register('zecrey', await owner.getAddress(), ownerL2Account);
            await registerTx.wait()
            expect(await zecreyLegend.getOwner(getNameHash('zecrey'))).to.equal(await owner.getAddress());
            expect(await zecreyLegend.getL2Owner(getNameHash('zecrey'))).to.equal(ownerL2Account);

            // transferL2
            const ownerL2Account2 = ethers.utils.formatBytes32String('test1')
            const transferTx = await zecreyLegend.connect(owner).transferL2(getNameHash('zecrey'), ownerL2Account2)
            await transferTx.wait()
            expect(await zecreyLegend.getOwner(getNameHash('zecrey'))).to.equal(await owner.getAddress());
            expect(await zecreyLegend.getL2Owner(getNameHash('zecrey'))).to.equal(ownerL2Account2);
        });
    });

    // get the keccak256 hash of a specified string name
    // eg: getKeccak256('zecrey') = '0x621eacce7c1f02dbf62859801a97d1b2903abc1c3e00e28acfb32cdac01ab36d'
    const getKeccak256 = (name) => {
        return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name))
    }

    // recursively get the keccak256 hash of a specified sub name with its parent node
    // eg: getNameHash('test.zecrey') = '0x41a39b3b92a0c1452758f455cd6d8d9d635e6ed5d48a89e74661da49e3a043a9'
    const getNameHash = (name) => {
        if (name === '') {
            return '\0' * 32;
        }

        if (name.includes('.')) {
            const parts = name.split('.', 2);
            const label = getKeccak256(parts[0])
            const remainder = getNameHash(parts[1])
            return ethers.utils.keccak256('0x' + remainder.replace('0x', '') + label.replace('0x', ''))
        } else {
            return getKeccak256(name)
        }
    }
});