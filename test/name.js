const {expect} = require("chai");
const {ethers} = require("hardhat");
const namehash = require('eth-ens-namehash')

describe("name hash", function () {

    // `beforeEach` will run before each test, re-deploying the contract every
    // time. It receives a callback, which can be async.
    beforeEach(async function () {
    });

    describe('ZNS Registry', function () {
        it("register", async function () {
            // register root node
            const hashVal = namehash.hash('sher.legend');
            console.log(hashVal)
        });
    });

    // get the keccak256 hash of a specified string name
    // eg: getKeccak256('zecrey') = '0x621eacce7c1f02dbf62859801a97d1b2903abc1c3e00e28acfb32cdac01ab36d'
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
    //     // split the name into 2 parts, if it contains '.', eg 'a.zecrey.legend' is split into 'a' and 'zecrey.legend'
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