// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "./UpgradableBank.sol";

contract StorageTest {

    // Test subcontract
    UpgradableBank internal bank;

    // Test storage
    uint32 public balance;

    /// @dev Flag indicates that upgrade preparation status is active
    /// @dev Will store false in case of not active upgrade mode
    bool internal upgradePreparationActive;

    /// @dev Upgrade preparation activation timestamp (as seconds since unix epoch)
    /// @dev Will be equal to zero in case of not active upgrade mode
    uint256 internal upgradePreparationActivationTime;

    /// @dev Upgrade start timestamp (as seconds since unix epoch)
    /// @dev Will be equal to zero in case of not active upgrade mode
    uint256 internal upgradeStartTimestamp;

    /// @dev Upgrade notice period, possibly shorten by the security council
    uint256 internal approvedUpgradeNoticePeriod;

    /// @dev Stores boolean flags which means the confirmations of the upgrade for each member of security council
    /// @dev Will store zeroes in case of not active upgrade mode
    mapping(uint256 => bool) internal securityCouncilApproves;
    uint256 internal numberOfApprovalsFromSecurityCouncil;

}
