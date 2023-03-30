// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPoseidonT3 {
  function poseidon(uint256[2] memory input) external pure returns (uint256);
}

interface IPoseidonT6 {
  function poseidon(uint256[5] memory input) external pure returns (uint256);
}

interface IPoseidonT7 {
  function poseidon(uint256[6] memory input) external pure returns (uint256);
}
