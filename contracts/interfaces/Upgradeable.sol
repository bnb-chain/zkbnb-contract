// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Interface of the upgradeable contract
/// @author ZkBNB Team
interface Upgradeable {
  /// @notice Upgrades target of upgradeable contract
  /// @param newTarget New target
  /// @param newTargetInitializationParameters New target initialization parameters
  function upgradeTarget(address newTarget, bytes calldata newTargetInitializationParameters) external;
}
