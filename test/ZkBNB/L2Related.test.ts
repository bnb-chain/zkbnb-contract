const { Client } = require('@bnb-chain/zkbas-js-sdk');
const {ethers} = require("hardhat");
const { ZkCrypto } = require('@bnb-chain/zkbas-js-sdk/zkCrypto');
import { getSeed } from '../util';


/**
 *  L2 should be running before running tests
 */
describe('L2 backend server', function () {
    before("init Client", async function () {
        const client = new Client('http://localhost:8888');
        const res = await client.getBlocks(0, 1);
        await client.getAccountByPubKey()
        await client.sendRawCreateCollectionTx()
        console.log(res)
    });
    it('should be able to connect to L2', async function () {
        const Z = await ZkCrypto();
        const ethWallet = ethers.getSigners()
        const sig = Z.signWithdraw(0, "temp")
        console.log('getEddsaPublicKey:', Z.getEddsaPublicKey('12312123123'))
        console.log(sig)
    });
});
