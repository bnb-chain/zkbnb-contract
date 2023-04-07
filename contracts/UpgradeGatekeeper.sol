// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./interfaces/Events.sol";
import "./interfaces/Upgradeable.sol";
import "./ZkBNBOwnable.sol";
import "./UpgradeableMaster.sol";

/// @title Upgrade Gatekeeper Contract
/// @dev A UpgradeGateKeeper is a manager of a group of upgradable contract
/// @author ZkBNB Team
contract UpgradeGatekeeper is UpgradeEvents, ZkBNBOwnable {
  /// @notice Upgrade mode statuses
  enum UpgradeStatus {
    Idle,
    NoticePeriod,
    Preparation
  }

  /// @notice Array of addresses of upgradeable contracts managed by the gatekeeper
  Upgradeable[] public managedContracts;

  UpgradeStatus public upgradeStatus;

  /// @notice Notice period finish timestamp (as seconds since unix epoch)
  /// @dev Will be equal to zero in case of not active upgrade mode
  uint256 public noticePeriodFinishTimestamp;

  /// @notice Addresses of the next versions of the contracts to be upgraded (if element of this array is equal to zero address it means that appropriate upgradeable contract wouldn't be upgraded this time)
  /// @dev Will be empty in case of not active upgrade mode
  address[] public nextTargets;

  /// @notice Version id of contracts
  uint256 public versionId;

  /// @notice Contract which defines notice period duration and allows finish upgrade during preparation of it
  UpgradeableMaster public masterContract;

  /// @notice Contract constructor
  /// @param _masterContract Contract which defines notice period duration and allows finish upgrade during preparation of it
  /// @dev Calls Ownable contract constructor
  constructor(UpgradeableMaster _masterContract) ZkBNBOwnable(msg.sender) {
    masterContract = _masterContract;
    versionId = 0;
  }

  /// @notice Adds a new upgradeable contract to the list of contracts managed by the gatekeeper
  /// @param addr Address of upgradeable contract to add
  function addUpgradeable(address addr) external onlyMaster {
    require(upgradeStatus == UpgradeStatus.Idle, "apc11");
    /// apc11 - upgradeable contract can't be added during upgrade

    managedContracts.push(Upgradeable(addr));
    emit NewUpgradable(versionId, addr);
  }

  /// @notice Starts upgrade (activates notice period)
  /// @param newTargets New managed contracts targets (if element of this array is equal to zero address it means that appropriate upgradeable contract wouldn't be upgraded this time)
  function startUpgrade(address[] calldata newTargets) external onlyMaster {
    require(upgradeStatus == UpgradeStatus.Idle, "spu11");
    // spu11 - unable to activate active upgrade mode
    require(newTargets.length == managedContracts.length, "spu12");
    // spu12 - number of new targets must be equal to the number of managed contracts

    // this noticePeriod is a configurable shortest notice period
    uint256 noticePeriod = masterContract.getNoticePeriod();
    masterContract.upgradeNoticePeriodStarted();
    upgradeStatus = UpgradeStatus.NoticePeriod;
    noticePeriodFinishTimestamp = block.timestamp + noticePeriod;
    nextTargets = newTargets;
    emit NoticePeriodStart(versionId, newTargets, noticePeriod);
  }

  /// @notice Cancels upgrade
  function cancelUpgrade() external onlyMaster {
    require(upgradeStatus != UpgradeStatus.Idle, "cpu11");
    // cpu11 - unable to cancel not active upgrade mode

    masterContract.upgradeCanceled();
    upgradeStatus = UpgradeStatus.Idle;
    noticePeriodFinishTimestamp = 0;
    delete nextTargets;
    emit UpgradeCancel(versionId);
  }

  /// @notice Activates preparation status
  function startPreparation() external onlyMaster {
    require(upgradeStatus == UpgradeStatus.NoticePeriod, "ugp11");
    // ugp11 - unable to activate preparation status in case of not active notice period status
    require(block.timestamp >= noticePeriodFinishTimestamp, "ugp12");
    // upg12 - shortest notice period not passed

    upgradeStatus = UpgradeStatus.Preparation;
    masterContract.upgradePreparationStarted();
    emit PreparationStart(versionId);
  }

  /// @notice Finishes upgrade
  /// @param targetsUpgradeParameters New targets upgrade parameters per each upgradeable contract
  function finishUpgrade(bytes[] calldata targetsUpgradeParameters) external onlyMaster {
    require(upgradeStatus == UpgradeStatus.Preparation, "fpu11");
    // fpu11 - unable to finish upgrade without preparation status active
    require(targetsUpgradeParameters.length == managedContracts.length, "fpu12");
    // fpu12 - number of new targets upgrade parameters must be equal to the number of managed contracts
    require(masterContract.isReadyForUpgrade(), "fpu13");
    // fpu13 - main contract is not ready for upgrade
    masterContract.upgradeFinishes();

    for (uint64 i = 0; i < managedContracts.length; ++i) {
      address newTarget = nextTargets[i];
      if (newTarget != address(0)) {
        managedContracts[i].upgradeTarget(newTarget, targetsUpgradeParameters[i]);
      }
    }
    ++versionId;
    emit UpgradeComplete(versionId, nextTargets);

    upgradeStatus = UpgradeStatus.Idle;
    noticePeriodFinishTimestamp = 0;
    delete nextTargets;
  }
}
