// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "../Config.sol";
import "./StorageTest.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "../SafeMathUInt128.sol";
import "../UpgradeableMaster.sol";


/// @dev Test target contract to upgrade to
contract ZecreyUpgradeTargetTest is UpgradeableMaster, Config, StorageTest {

    using SafeMath for uint256;
    using SafeMathUInt128 for uint128;

    function initialize(bytes calldata initializationParameters) external {
        (address _bankAddr) = abi.decode(initializationParameters, (address));
        bank = UpgradableBank(_bankAddr);
    }

    function setBalance(uint32 lambda) external {
        balance += (lambda * 5);
    }

    function setBankBalance(uint32 lambda) external {
        bank.setBankBalance(lambda);
    }

    // Upgrade functional

    /// @notice Notice period before activation preparation status of upgrade mode
    function getNoticePeriod() external pure override returns (uint256) {
        return 0;
    }

    /// @notice Notification that upgrade notice period started
    /// @dev Can be external because Proxy contract intercepts illegal calls of this function
    function upgradeNoticePeriodStarted() external override {
        upgradeStartTimestamp = block.timestamp;
    }

    /// @notice Notification that upgrade preparation status is activated
    /// @dev Can be external because Proxy contract intercepts illegal calls of this function
    function upgradePreparationStarted() external override {
        upgradePreparationActive = true;
        upgradePreparationActivationTime = block.timestamp;

        require(block.timestamp >= upgradeStartTimestamp.add(approvedUpgradeNoticePeriod));
    }

    /// @notice Notification that upgrade canceled
    /// @dev Can be external because Proxy contract intercepts illegal calls of this function
    function upgradeCanceled() external override {
        clearUpgradeStatus();
    }

    /// @notice Notification that upgrade finishes
    /// @dev Can be external because Proxy contract intercepts illegal calls of this function
    function upgradeFinishes() external override {
        clearUpgradeStatus();
    }

    /// @notice Checks that contract is ready for upgrade
    /// @return bool flag indicating that contract is ready for upgrade
    function isReadyForUpgrade() external pure override returns (bool) {
        return true;
    }

    /// @dev When upgrade is finished or canceled we must clean upgrade-related state.
    function clearUpgradeStatus() internal {
        upgradePreparationActive = false;
        upgradePreparationActivationTime = 0;
        approvedUpgradeNoticePeriod = UPGRADE_NOTICE_PERIOD;
        upgradeStartTimestamp = 0;
        for (uint256 i = 0; i < SECURITY_COUNCIL_MEMBERS_NUMBER; ++i) {
            securityCouncilApproves[i] = false;
        }
        numberOfApprovalsFromSecurityCouncil = 0;
    }

    function upgrade(bytes calldata upgradeParameters) external {
        balance += 12;
    }
}


