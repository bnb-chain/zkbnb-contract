// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceOracle {
  /**
   * @dev Returns the price to register a name.
   * @param name The name being registered.
   * @return price
   */
  function price(string calldata name) external view returns (uint256);
}
