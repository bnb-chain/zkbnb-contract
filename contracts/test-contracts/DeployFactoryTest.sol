// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "./ZecreyUpgradeTest.sol";
import "../Proxy.sol";
import "../UpgradeGatekeeper.sol";

contract DeployFactoryTest {

    constructor(
        ZecreyUpgradeTest _zecreyTarget,
        UpgradableBank _bank
    ) {
        deployProxyContracts(_zecreyTarget, _bank);
        selfdestruct(msg.sender);
    }

    event Addresses(address zecrey, address bank, address gatekeeper);

    function deployProxyContracts(
        ZecreyUpgradeTest _zecreyTest,
        UpgradableBank _bank
    ) internal {
        Proxy bank = new Proxy(address(_bank), abi.encode());
        Proxy zecrey = new Proxy(address(_zecreyTest), abi.encode(address(bank)));

        UpgradeGatekeeper upgradeGatekeeper = new UpgradeGatekeeper(zecrey);

        zecrey.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(zecrey));

        bank.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(bank));

        // New master is a governor
        upgradeGatekeeper.transferMastership(msg.sender);

        emit Addresses(address(zecrey), address(bank), address(upgradeGatekeeper));
    }

}
