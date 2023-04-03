// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

library Names {
  /**
   * @dev Returns the length of a given string, the length of each byte is self defined
   * @param s The string to measure the length of
   * @return The length of the input string
   */
  function strlen(string memory s) internal pure returns (uint) {
    uint len;
    uint i = 0;
    uint bytelength = bytes(s).length;
    for (len = 0; i < bytelength; ++len) {
      bytes1 b = bytes(s)[i];
      if (b <= 0x80) {
        i += 1;
      } else if (b < 0xE0) {
        i += 2;
      } else if (b < 0xF0) {
        i += 3;
      } else if (b < 0xF8) {
        i += 4;
      } else if (b < 0xFC) {
        i += 5;
      } else {
        i += 6;
      }
    }
    return len;
  }

  /**
   * @dev Returns if the char in this string is valid, the valid char set is self defined
   * @param s The string to validate
   * @return The length of the input string
   */
  function charsetValid(string memory s) internal pure returns (bool) {
    uint bytelength = bytes(s).length;
    for (uint i = 0; i < bytelength; ++i) {
      bytes1 b = bytes(s)[i];
      if (!isValidCharacter(b)) {
        return false;
      }
    }
    return true;
  }

  // Only supports lowercase letters and digital number
  function isValidCharacter(bytes1 bs) internal pure returns (bool) {
    return (bs <= 0x39 && bs >= 0x30) || (bs <= 0x7A && bs >= 0x61); // number or lowercase letter
  }
}
