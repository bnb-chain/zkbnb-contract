pragma solidity ^0.7.6;

import "./IPriceOracle.sol";
import "./utils/Names.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

// StablePriceOracle sets a price for zns name in BNB
contract StablePriceOracle is IPriceOracle, OwnableUpgradeable {
    using Names for string;

    // Rent in base price units by length
    uint256 public price1Letter;
    uint256 public price2Letter;
    uint256 public price3Letter;

    event RentPriceChanged(uint256[] prices);

    constructor(uint256[] memory _rentPrices) {
        __Ownable_init();

        price1Letter = _rentPrices[0];
        price2Letter = _rentPrices[1];
        price3Letter = _rentPrices[2];
        emit RentPriceChanged(_rentPrices);
    }

    function changeRentPrice(uint256[] memory _rentPrices) external onlyOwner {
        price1Letter = _rentPrices[0];
        price2Letter = _rentPrices[1];
        price3Letter = _rentPrices[2];
        emit RentPriceChanged(_rentPrices);
    }

    function price(string calldata name) external view override returns (uint256) {
        uint256 len = name.strlen();
        uint256 basePrice;
        if (len >= 3 && len < 10) {
            basePrice = price1Letter;
        } else if (len >= 10 && len < 20) {
            basePrice = price2Letter;
        } else {
            basePrice = price3Letter;
        }

        return BNBToWei(basePrice);
    }

    function BNBToWei(uint256 amount) internal view returns (uint256) {
        return amount * 1e18;
    }
}
