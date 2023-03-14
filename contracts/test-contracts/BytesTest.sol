// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "../lib/Bytes.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract BytesTest {
  function bytes32ToHexString(bytes32 hash) external view returns (string memory) {
    return Bytes.bytes32ToHexString(hash, true);
  }

  function bytes32ToHexStringWithoutPrefix(bytes32 hash) external view returns (string memory) {
    return Bytes.bytes32ToHexString(hash, false);
  }

  function concatStringAndBytes32(string calldata prefix, bytes32 hash) external view returns (string memory) {
    return string(abi.encodePacked(prefix, Bytes.bytes32ToHexString(hash, false)));
  }

  function sliceBytes(bytes memory _bytes, uint256 start, uint256 length) external view returns (bytes memory) {
    return Bytes.slice(_bytes, start, length);
  }
}
