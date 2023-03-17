// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../lib/TxTypes.sol";

contract TxTypesTest {
  function testWriteFullExitPubData(TxTypes.FullExit memory _tx) external pure returns (bytes memory buf) {
    return TxTypes.writeFullExitPubDataForPriorityQueue(_tx);
  }

  function testReadFullExitPubData(bytes memory _data) external pure returns (TxTypes.FullExit memory parsed) {
    return TxTypes.readFullExitPubData(_data);
  }

  function testWriteFullExitNftPubData(TxTypes.FullExitNft memory _tx) external pure returns (bytes memory buf) {
    return TxTypes.writeFullExitNftPubDataForPriorityQueue(_tx);
  }

  function testReadFullExitNftPubData(bytes memory _data) external pure returns (TxTypes.FullExitNft memory parsed) {
    return TxTypes.readFullExitNftPubData(_data);
  }

  function testReadChangePubKeyPubData(bytes memory _data) external pure returns (TxTypes.ChangePubKey memory parsed) {
    return TxTypes.readChangePubKeyPubData(_data);
  }

  function testReadWithdrawPubData(bytes memory _data) external pure returns (TxTypes.Withdraw memory parsed) {
    return TxTypes.readWithdrawPubData(_data);
  }

  function testReadWithdrawNftPubData(bytes memory _data) external pure returns (TxTypes.WithdrawNft memory parsed) {
    return TxTypes.readWithdrawNftPubData(_data);
  }

  function testWriteDepositPubData(TxTypes.Deposit memory _tx) external pure returns (bytes memory buf) {
    return TxTypes.writeDepositPubDataForPriorityQueue(_tx);
  }

  function testReadDepositPubData(bytes memory _data) external pure returns (TxTypes.Deposit memory parsed) {
    return TxTypes.readDepositPubData(_data);
  }

  function testWriteDepositNftPubData(TxTypes.DepositNft memory _tx) external pure returns (bytes memory buf) {
    return TxTypes.writeDepositNftPubDataForPriorityQueue(_tx);
  }

  function testReadDepositNftPubData(bytes memory _data) external pure returns (TxTypes.DepositNft memory parsed) {
    return TxTypes.readDepositNftPubData(_data);
  }
}
