// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

contract UpgradableBank {

    uint32 public bankBalance;

    function setBankBalance(uint32 lambda) external {
        bankBalance += lambda;
    }

    function initialize(bytes calldata initializationParameters) external {}

    function upgrade(bytes calldata upgradeParameters) external {}

}
