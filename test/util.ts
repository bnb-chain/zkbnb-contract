import { Signer, utils } from 'ethers';

import log from '../logger.config';
import { ethers } from 'hardhat';
import { ZkCrypto } from '@bnb-chain/zkbnb-js-sdk/zkCrypto';
import { Client } from '@bnb-chain/zkbnb-js-sdk';

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

        // eslint-disable-next-line @typescript-eslint/ban-ts-comment
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
        const client = new Client('http://172.22.41.67:8888');
        const res = await client.getAccountByPubKey(compressedPublicKey);
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
    let message = 'Access zkbas account.\n\nOnly sign this message for a trusted client!';
    if (chainID !== 1) {
        message += `\nChain ID: ${chainID}.`;
    }

    const bytesToSign = getSignedBytesFromMessage(message, false);
    const signature = await signMessagePersonalAPI(ethSigner, bytesToSign);
    const seed = utils.arrayify(signature);
    return { seed };
};

const signMessagePersonalAPI = async (signer: Signer, message: Uint8Array): Promise<string> => {
    if (!signer) return '';
    if (signer instanceof ethers.providers.JsonRpcSigner) {
        return signer.provider.send('personal_sign', [utils.hexlify(message), await signer.getAddress()]).then(
            (sign) => sign,
            (err) => {
                // We check for method name in the error string because error messages about invalid method name
                // often contain method name.
                if (err.message.includes('personal_sign')) {
                    // If no "personal_sign", use "eth_sign"
                    return signer.signMessage(message);
                }
                log.error('Signing message failed', err);
                throw err;
            },
        );
    } else {
        return signer.signMessage(message);
    }
};

const getSignedBytesFromMessage = (message: utils.BytesLike | string, addPrefix: boolean): Uint8Array => {
    let messageBytes = typeof message === 'string' ? utils.toUtf8Bytes(message) : utils.arrayify(message);
    if (addPrefix) {
        messageBytes = utils.concat([
            utils.toUtf8Bytes(`\x19Ethereum Signed Message:\n${messageBytes.length}`),
            messageBytes,
        ]);
    }
    return messageBytes;
};

export const getSeed = async (signer: any) => {
    return Uint8Array.from(
        (await generateSeed(signer)).seed
            .toString()
            .split(',')
            .map((x: any) => +x),
    );
};

function toHexString(byteArray: any) {
    return Array.prototype.map
        .call(byteArray, function(byte) {
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
    return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name));
};

export const transferFunds = async (signer: any, to: string, amount: string) => {
    const tx = await signer.sendTransaction({
        from: await signer.getAddress(),
        to,
        value: ethers.utils.parseEther(amount),
    });
    await tx.wait();
};

export interface StoredBlockInfo {
    blockSize: number;
    blockNumber: number;
    priorityOperations: number;
    pendingOnchainOperationsHash: string;
    timestamp: number;
    stateRoot: string;
    commitment: string;
}

export interface OnchainOperationData {
    ethWitness: string;
    publicDataOffset: number;
}

export interface CommitBlockInfo {
    newStateRoot: string;
    publicData: string;
    timestamp: number;
    onchainOperations: OnchainOperationData[];
    blockNumber: number;
    blockSize: number;
}

export interface VerifyAndExecuteBlockInfo {
    blockHeader: StoredBlockInfo;
    pendingOnchainOpsPubData: string[];
}

export function hashStoredBlockInfo(block: StoredBlockInfo) {
    const encode = ethers.utils.defaultAbiCoder.encode(
        ['uint16', 'uint32', 'uint64', 'bytes32', 'uint256', 'bytes32', 'bytes32'],
        [
            block.blockSize,
            block.blockNumber,
            block.priorityOperations,
            block.pendingOnchainOperationsHash,
            block.timestamp,
            block.stateRoot,
            block.commitment,
        ],
    );
    return ethers.utils.keccak256(encode);
}
export enum PubDataType {
    EmptyTx,
    ChangePubKey,
    Deposit,
    DepositNft,
    Transfer,
    Withdraw,
    CreateCollection,
    MintNft,
    TransferNft,
    AtomicMatch,
    CancelOffer,
    WithdrawNft,
    FullExit,
    FullExitNft,
}

export function encodePubData(pubDataType: string[], pubData: any[]) {
    return ethers.utils.solidityPack(pubDataType, pubData);
}

export function encodePackPubData(pubDataType: string[], pubData: any[]) {
    let data = ethers.utils.solidityPack(pubDataType, pubData);

    while (data.length < 121 * 2 + 2) {
        data += '00';
    }

    return data;
}

export function padEndBytes121(data: string) {
    while (data.length < 121 * 2 + 2) {
        data += '00';
    }

    return data;
}

export const PubDataTypeMap = {
    [PubDataType.ChangePubKey]: ['uint8', 'uint32', 'bytes32', 'bytes32', 'bytes20', 'uint32'],
    [PubDataType.Deposit]: ['uint8', 'uint32', 'address', 'uint16', 'uint128'],
    [PubDataType.DepositNft]: ['uint8', 'uint32', 'uint40', 'uint32', 'uint16', 'uint16', 'bytes32', 'bytes32'],
    [PubDataType.Withdraw]: ['uint8', 'uint32', 'address', 'uint16', 'uint128', 'uint16', 'uint16'],
    [PubDataType.WithdrawNft]: [
        'uint8',
        'uint32',
        'uint32',
        'uint16',
        'uint40',
        'address',
        'uint32',
        'uint16',
        'uint16',
        'bytes32',
        'bytes32',
        'uint32',
    ],
    [PubDataType.FullExit]: ['uint8', 'uint32', 'uint16', 'uint128', 'bytes32'],
    [PubDataType.FullExitNft]: [
        'uint8',
        'uint32',
        'uint32',
        'uint16',
        'uint40',
        'uint16',
        'bytes32',
        'bytes32',
        'bytes32',
    ],
};
export const EMPTY_STRING_KECCAK = '0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470';

export function numberToBytesBE(number: number, bytes: number): Uint8Array {
    const result = new Uint8Array(bytes);
    for (let i = bytes - 1; i >= 0; i--) {
        result[i] = number & 0xff;
        number >>= 8;
    }
    return result;
}

export function serializeNonce(nonce: number): Uint8Array {
    return numberToBytesBE(nonce, 4);
}

export function serializeAccountIndex(accountIndex: number): Uint8Array {
    return numberToBytesBE(accountIndex, 4);
}

export function getChangePubkeyMessage(
    pubKeyX: string,
    pubKeyY: string,
    nonce: number,
    accountIndex: number,
): Uint8Array {
    const msgNonce = utils.hexlify(serializeNonce(nonce));
    const msgAccountIndex = utils.hexlify(serializeAccountIndex(accountIndex));
    const message =
        `Register zkBNB Account\n\n` +
        `pubkeyX: ` +
        `${pubKeyX}\n` +
        `pubkeyY: ` +
        `${pubKeyY}\n` +
        `nonce: ${msgNonce}\n` +
        `account index: ${msgAccountIndex}\n\n` +
        `Only sign this message for a trusted client!`;
    return utils.toUtf8Bytes(message);
}
