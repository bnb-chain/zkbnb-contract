// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPoseidon {
  function poseidonInputs2(uint256[2] memory) external pure returns (uint256);

  function poseidonInputs5(uint256[5] memory) external pure returns (uint256);

  function poseidonInputs6(uint256[6] memory) external pure returns (uint256);
}
