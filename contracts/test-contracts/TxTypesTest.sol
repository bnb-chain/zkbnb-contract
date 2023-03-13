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
}