// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "./ZkbasUpgradeTest.sol";
import "../Proxy.sol";
import "../UpgradeGatekeeper.sol";

contract DeployFactoryTest {

    constructor(
        ZkbasUpgradeTest _zkbasTarget,
        UpgradableBank _bank
    ) {
        deployProxyContracts(_zkbasTarget, _bank);
        selfdestruct(msg.sender);
    }

    event Addresses(address zkbas, address bank, address gatekeeper);

    function deployProxyContracts(
        ZkbasUpgradeTest _zkbasTest,
        UpgradableBank _bank
    ) internal {
        Proxy bank = new Proxy(address(_bank), abi.encode());
        Proxy zkbas = new Proxy(address(_zkbasTest), abi.encode(address(bank)));

        UpgradeGatekeeper upgradeGatekeeper = new UpgradeGatekeeper(zkbas);

        zkbas.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(zkbas));

        bank.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(bank));

        // New master is a governor
        upgradeGatekeeper.transferMastership(msg.sender);

        emit Addresses(address(zkbas), address(bank), address(upgradeGatekeeper));
    }

}
