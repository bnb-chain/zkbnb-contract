// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./interfaces/IPriceOracle.sol";
import "./lib/Names.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PriceOracleV1 is IPriceOracle, Ownable {
  using Names for string;

  // Price for names with size 1 - 6
  uint256 public priceForSmallNames;

  event PriceChanged(uint256 price);

  constructor(uint256 priceForSmallNames_) {
    priceForSmallNames = priceForSmallNames_;
    emit PriceChanged(priceForSmallNames_);
  }

  function changePrice(uint256 priceForSmallNames_) external onlyOwner {
    priceForSmallNames = priceForSmallNames_;
    emit PriceChanged(priceForSmallNames_);
  }

  function price(string calldata name) external view override returns (uint256) {
    uint256 len = name.strlen();
    require(name.charsetValid() && len >= 1, "invalid name");
    uint256 basePrice;
    if (len < 7) {
      basePrice = priceForSmallNames;
    } else {
      basePrice = 0 ether;
    }
    return basePrice;
  }
}
