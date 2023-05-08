// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./Bytes.sol";
import "./TxTypes.sol";
import "../Storage.sol";

library Utils {
  bytes constant SHA256_MULTI_HASH = hex"1220";
  bytes constant ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

  function stringToBytes20(string memory source) public pure returns (bytes20 result) {
    bytes memory tempEmptyStringTest = bytes(source);
    if (tempEmptyStringTest.length == 0) {
      return 0x0;
    }

    assembly {
      result := mload(add(source, 32))
    }
  }

  /// @notice Returns lesser of two values
  function minU32(uint32 a, uint32 b) internal pure returns (uint32) {
    return a < b ? a : b;
  }

  /// @notice Returns lesser of two values
  function minU64(uint64 a, uint64 b) internal pure returns (uint64) {
    return a < b ? a : b;
  }

  /// @notice Returns lesser of two values
  function minU128(uint128 a, uint128 b) internal pure returns (uint128) {
    return a < b ? a : b;
  }

  /// @notice Recovers signer's address from ethereum signature for given message
  /// @param _signature 65 bytes concatenated. R (32) + S (32) + V (1)
  /// @param _messageHash signed message hash.
  /// @return address of the signer
  function recoverAddressFromEthSignature(
    bytes memory _signature,
    bytes32 _messageHash
  ) internal pure returns (address) {
    require(_signature.length == 65, "P");
    // incorrect signature length

    bytes32 signR;
    bytes32 signS;
    uint8 signV;
    assembly {
      signR := mload(add(_signature, 32))
      signS := mload(add(_signature, 64))
      signV := byte(0, mload(add(_signature, 96)))
    }

    address recoveredAddress = ecrecover(_messageHash, signV, signR, signS);
    require(recoveredAddress != address(0), "R");

    return recoveredAddress;
  }

  /// @notice Returns new_hash = hash(old_hash + bytes)
  /// @param _bytes Pubdata to be hashed; should not be used again once passed to this function since the length might change
  function concatHash(bytes32 _hash, bytes memory _bytes) internal pure returns (bytes32) {
    bytes32 result;
    assembly {
      let bytesLen := add(mload(_bytes), 32)
      mstore(_bytes, _hash)
      result := keccak256(_bytes, bytesLen)
    }
    return result;
  }

  function hashBytesToBytes20(bytes memory _bytes) internal pure returns (bytes20) {
    // downcast uint160 to take lowest 20 bytes
    return bytes20(uint160(uint256(keccak256(_bytes))));
  }

  function bytesToUint256Arr(bytes memory _pubData) internal pure returns (uint256[] memory pubData) {
    uint256 bytesCount = _pubData.length / 32;
    pubData = new uint256[](bytesCount);
    uint256 q = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    for (uint32 i = 0; i < bytesCount; ++i) {
      bytes32 result = Bytes.bytesToBytes32(Bytes.slice(_pubData, i * 32, 32), 0);
      pubData[i] = uint256(result) % q;
    }
    return pubData;
  }

  /// @notice Checks that signature is valid for pubkey change message
  /// @param _ethWitness Version(1 byte) and signature (65 bytes)
  /// @param _changePk Parsed change pubkey tx type
  function verifyChangePubkey(
    bytes memory _ethWitness,
    TxTypes.ChangePubKey memory _changePk
  ) external pure returns (bool) {
    (, bytes memory signature) = Bytes.read(_ethWitness, 1, 65); // offset is 1 because we skip type of ChangePubkey

    bytes32 messageHash = keccak256(
      abi.encodePacked(
        "\x19Ethereum Signed Message:\n265",
        "Register zkBNB Account\n\n",
        "pubkeyX: 0x",
        Bytes.bytesToHexASCIIBytes(abi.encodePacked(_changePk.pubkeyX)),
        "\n",
        "pubkeyY: 0x",
        Bytes.bytesToHexASCIIBytes(abi.encodePacked(_changePk.pubkeyY)),
        "\n",
        "nonce: 0x",
        Bytes.bytesToHexASCIIBytes(Bytes.toBytesFromUInt32(_changePk.nonce)),
        "\n",
        "account index: 0x",
        Bytes.bytesToHexASCIIBytes(Bytes.toBytesFromUInt32(_changePk.accountIndex)),
        "\n\n",
        "Only sign this message for a trusted client!"
      )
    );
    address recoveredAddress = Utils.recoverAddressFromEthSignature(signature, messageHash);
    return recoveredAddress == _changePk.owner;
  }

  /// @dev Converts hex string to base 58
  function toBase58(bytes memory source) internal pure returns (string memory) {
    uint8[] memory digits = new uint8[](46);
    digits[0] = 0;
    uint8 digitLength = 1;
    for (uint8 i = 0; i < source.length; ++i) {
      uint256 carry = uint8(source[i]);
      for (uint32 j = 0; j < digitLength; ++j) {
        carry += uint256(digits[j]) * 256;
        digits[j] = uint8(carry % 58);
        carry = carry / 58;
      }

      while (carry > 0) {
        digits[digitLength] = uint8(carry % 58);
        digitLength++;
        carry = carry / 58;
      }
    }
    return toAlphabet(reverse(digits));
  }

  function ipfsCID(bytes32 source) public pure returns (string memory) {
    return toBase58(abi.encodePacked(SHA256_MULTI_HASH, source));
  }

  function reverse(uint8[] memory input) internal pure returns (uint8[] memory) {
    uint8[] memory output = new uint8[](input.length);
    for (uint8 i = 0; i < input.length; i++) {
      output[i] = input[input.length - 1 - i];
    }
    return output;
  }

  function toAlphabet(uint8[] memory indices) internal pure returns (string memory) {
    bytes memory output = new bytes(indices.length);
    for (uint32 i = 0; i < indices.length; i++) {
      output[i] = ALPHABET[indices[i]];
    }
    return string(output);
  }
}
