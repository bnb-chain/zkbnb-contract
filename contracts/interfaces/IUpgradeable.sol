// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Interface of the upgradeable contract
/// @author ZkBNB Team
interface IUpgradeable {
  /// @notice Upgrades target of upgradeable contract
  /// @param newTarget New target
  /// @param newTargetInitializationParameters New target initialization parameters
  function upgradeTarget(address newTarget, bytes calldata newTargetInitializationParameters) external;

  /**
   * @dev Emitted when the implementation is upgraded.
   */
  event Upgraded(address indexed implementation);
}
