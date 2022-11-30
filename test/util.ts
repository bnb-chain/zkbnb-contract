import {Signer, utils} from 'ethers';
const { zkbasClient } = require('@bnb-chain/zkbas-js-sdk');
import log from "../logger.config";
import {ethers} from "hardhat";
const { ZkCrypto } = require('@bnb-chain/zkbas-js-sdk/zkCrypto');

export const registerUser = async (signer: any, contract: any, name: string, address: string) => {
    if (!name || name.length === 0) return;

    const seed = await getSeed(signer);
    const { x, y } = await getPublicKey(seed);
    const price = await contract.getZNSNamePrice(name);

    let validName = false;
    try {
        validName = await contract.isRegisteredZNSName(name);
    } catch (err) {
       log.error(err);
    }

    if (validName) {
        log.error('Name already registered');
        return;
    }

    let registerResult = null;
    try {
        registerResult = await contract.registerZNS(name, address, x, y, {
            value: price,
        });

        // @ts-ignore
        await registerResult.wait();
    } catch (err: any) {
        log.error(err);
        return;
    }
    return registerResult;
};

// Whether it has been registered
// true: registered
// false: not register
export const getL2UserInfo = async () => {
    const ethWallet = await ethers.getSigners();
    const seed = await getSeed(ethWallet[0]);

    const { compressedPublicKey } = await getPublicKey(seed);

    try {
        const res = await zkbasClient.getAccountByPubKey(compressedPublicKey);
        return res;
    } catch (err) {
       log.error(err);
    }
    return null;
};

const getSeedKey = async (ethSigner: any) => {
    const network = await ethers.getDefaultProvider().getNetwork();
    const chainId = network.chainId;
    const address = await ethSigner.getAddress();
    return `${chainId}-${address}`;
};


const generateSeed = async (ethSigner: any) => {
    let chainID = 1;
    if (ethSigner && ethSigner.provider) {
        const network = await ethSigner.provider.getNetwork();
        chainID = network.chainId;
    }
    let message = 'Test message';
    if (chainID !== 1) {
        message += `\nChain ID: ${chainID}.`;
    }

    const bytesToSign = getSignedBytesFromMessage(message, false);
    const signature = await signMessagePersonalAPI(ethSigner, bytesToSign);
    const seed = utils.arrayify(signature);
    return { seed };
};

const signMessagePersonalAPI = async (
    signer: Signer,
    message: Uint8Array,
): Promise<string> => {
    if (!signer) return '';
    if (signer instanceof ethers.providers.JsonRpcSigner) {
        return signer.provider
            .send('personal_sign', [utils.hexlify(message), await signer.getAddress()])
            .then(
                (sign) => sign,
                (err) => {
                    // We check for method name in the error string because error messages about invalid method name
                    // often contain method name.
                    if (err.message.includes('personal_sign')) {
                        // If no "personal_sign", use "eth_sign"
                        return signer.signMessage(message);
                    }
                    log.error("Signing message failed", err);
                    throw err;
                },
            );
    } else {
        return signer.signMessage(message);
    }
};

const getSignedBytesFromMessage = (
    message: utils.BytesLike | string,
    addPrefix: boolean,
): Uint8Array => {
    let messageBytes =
        typeof message === 'string' ? utils.toUtf8Bytes(message) : utils.arrayify(message);
    if (addPrefix) {
        messageBytes = utils.concat([
            utils.toUtf8Bytes(`\x19Ethereum Signed Message:\n${messageBytes.length}`),
            messageBytes,
        ]);
    }
    return messageBytes;
};

export const getSeed = async (signer: any) => {

    return Uint8Array.from((await generateSeed(signer)).seed
        .toString()
        .split(',')
        .map((x: any) => +x));
};

function toHexString(byteArray: any) {
  return Array.prototype.map
    .call(byteArray, function (byte) {
      return ('0' + (byte & 0xff).toString(16)).slice(-2);
    })
    .join('');
}

export const getPublicKey = async (seed: any) => {
    const seedString = new TextDecoder().decode(seed);

    const publicKey = ZkCrypto.getEddsaPublicKey(seedString);
    const compressedPublicKey = ZkCrypto.getEddsaCompressedPublicKey(seedString);

    const x = `0x${publicKey.slice(0, 64)}`;
    const y = `0x${publicKey.slice(64)}`;
    return {
        publicKey,
        compressedPublicKey,
        x,
        y,
    };
};

export const getAccountNameHash = async (accountName: string) => {
    return ZkCrypto.getAccountNameHash(accountName);
};

export const getKeccak256 = (name) => {
    return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name))
}
