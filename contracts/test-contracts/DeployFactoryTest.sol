// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "./ZkBNBUpgradeTest.sol";
import "../Proxy.sol";
import "../UpgradeGatekeeper.sol";

contract DeployFactoryTest {

    constructor(
        ZkBNBUpgradeTest _zkbnbTarget,
        UpgradableBank _bank
    ) {
        deployProxyContracts(_zkbnbTarget, _bank);
        selfdestruct(msg.sender);
    }

    event Addresses(address zkbnb, address bank, address gatekeeper);

    function deployProxyContracts(
        ZkBNBUpgradeTest _zkbnbTest,
        UpgradableBank _bank
    ) internal {
        Proxy bank = new Proxy(address(_bank), abi.encode());
        Proxy zkbnb = new Proxy(address(_zkbnbTest), abi.encode(address(bank)));

        UpgradeGatekeeper upgradeGatekeeper = new UpgradeGatekeeper(zkbnb);

        zkbnb.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(zkbnb));

        bank.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(bank));

        // New master is a governor
        upgradeGatekeeper.transferMastership(msg.sender);

        emit Addresses(address(zkbnb), address(bank), address(upgradeGatekeeper));
    }

}
