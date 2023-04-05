import { utils } from 'ethers';

import { ethers } from 'hardhat';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

export const getKeccak256 = (name) => {
  return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name));
};

export const transferFunds = async (signer: SignerWithAddress, to: string, amount: string) => {
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

export function encodePubData(pubDataType: string[], pubData: ReadonlyArray<any>) {
  return ethers.utils.solidityPack(pubDataType, pubData);
}

export function encodePackPubData(pubDataType: string[], pubData: ReadonlyArray<any>) {
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
