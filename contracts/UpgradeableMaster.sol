// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Config.sol";
import "./Storage.sol";
import "./interfaces/IZkBNBDesertMode.sol";

/// @title upgradeable master contract (defines notice period duration and allows finish upgrade during preparation of it)
/// @author ZkBNB Team
contract UpgradeableMaster is AccessControl {
  // Create a new role identifier for the UpgradeGatekeeper
  bytes32 public constant UPGRADE_GATEKEEPER_ROLE = keccak256("UPGRADE_GATEKEEPER_ROLE");

  /// @dev Configurable notice period
  uint256 public constant UPGRADE_NOTICE_PERIOD = 4 weeks;
  /// @dev Shortest notice period
  uint256 public constant SHORTEST_UPGRADE_NOTICE_PERIOD = 0;

  uint256 internal constant SECURITY_COUNCIL_THRESHOLD = 3;

  IZkBNBDesertMode public zkBNB;
  address[] public securityCouncilMembers;

  /// @dev Flag indicates that upgrade preparation status is active
  /// @dev Will store false in case of not active upgrade mode
  bool internal upgradePreparationActive;

  /// @dev Upgrade preparation activation timestamp (as seconds since unix epoch)
  /// @dev Will be equal to zero in case of not active upgrade mode
  uint256 internal _upgradePreparationActivationTime;

  /// @dev Upgrade notice period, possibly shorten by the security council
  uint256 internal _approvedUpgradeNoticePeriod;

  /// @dev Upgrade start timestamp (as seconds since unix epoch)
  /// @dev Will be equal to zero in case of not active upgrade mode
  uint256 internal _upgradeStartTimestamp;

  /// @dev Stores boolean flags which means the confirmations of the upgrade for each member of security council
  /// @dev Will store zeroes in case of not active upgrade mode
  mapping(uint256 => bool) internal _securityCouncilApproves;
  uint256 internal _numberOfApprovalsFromSecurityCouncil;

  event NoticePeriodChange(uint256 newNoticePeriod);
  event ZkBNBChanged(address zkBNB);
  event SecurityCouncilChanged(address[3] securityCouncilMembers);
  event SecurityCouncilApproved(uint256 numberOfApprovalsFromSecurityCouncil);

  constructor(address[3] memory _securityCouncilMembers, address _zkBNB) {
    securityCouncilMembers = _securityCouncilMembers;

    zkBNB = IZkBNBDesertMode(_zkBNB);

    // Set default admin
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

    _approvedUpgradeNoticePeriod = UPGRADE_NOTICE_PERIOD;
    emit NoticePeriodChange(_approvedUpgradeNoticePeriod);
  }

  function changeSecurityCouncilMembers(
    address[3] memory _securityCouncilMembers
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    securityCouncilMembers = _securityCouncilMembers;
    emit SecurityCouncilChanged(_securityCouncilMembers);
  }

  function changeZkBNBAddress(address _zkBNB) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(_zkBNB != address(0), "nz");
    zkBNB = IZkBNBDesertMode(_zkBNB);

    emit ZkBNBChanged(_zkBNB);
  }

  /// @notice Notification that upgrade notice period started
  function upgradeNoticePeriodStarted() external onlyRole(UPGRADE_GATEKEEPER_ROLE) {
    _upgradeStartTimestamp = block.timestamp;
  }

  /// @notice Notification that upgrade preparation status is activated
  function upgradePreparationStarted() external onlyRole(UPGRADE_GATEKEEPER_ROLE) {
    upgradePreparationActive = true;
    _upgradePreparationActivationTime = block.timestamp;
    // Check if the _approvedUpgradeNoticePeriod is passed
    require(block.timestamp >= _upgradeStartTimestamp + _approvedUpgradeNoticePeriod, "upf");
  }

  /// @notice Notification that upgrade canceled
  function upgradeCanceled() external onlyRole(UPGRADE_GATEKEEPER_ROLE) {
    clearUpgradeStatus();
  }

  /// @notice Notification that upgrade finishes
  function upgradeFinishes() external onlyRole(UPGRADE_GATEKEEPER_ROLE) {
    clearUpgradeStatus();
  }

  /// @notice processing new approval of decrease upgrade notice period time to zero
  function cutUpgradeNoticePeriod() external {
    require(!zkBNB.desertMode());

    for (uint256 id = 0; id < securityCouncilMembers.length; ++id) {
      if (securityCouncilMembers[id] == msg.sender) {
        require(_upgradeStartTimestamp != 0, "ust");
        require(!_securityCouncilApproves[id], "scf");
        _securityCouncilApproves[id] = true;
        ++_numberOfApprovalsFromSecurityCouncil;
        emit SecurityCouncilApproved(_numberOfApprovalsFromSecurityCouncil);

        if (_numberOfApprovalsFromSecurityCouncil == SECURITY_COUNCIL_THRESHOLD) {
          if (_approvedUpgradeNoticePeriod > 0) {
            _approvedUpgradeNoticePeriod = 0;
            emit NoticePeriodChange(_approvedUpgradeNoticePeriod);
          }
        }
        break;
      }
    }
  }

  /// @notice Checks that contract is ready for upgrade
  /// @return bool flag indicating that contract is ready for upgrade
  function isReadyForUpgrade() external view returns (bool) {
    return !zkBNB.desertMode();
  }

  // Upgrade functional
  /// @notice Shortest Notice period before activation preparation status of upgrade mode
  ///         Notice period can be set by secure council
  function getNoticePeriod() external pure returns (uint256) {
    return SHORTEST_UPGRADE_NOTICE_PERIOD;
  }

  /// @dev When upgrade is finished or canceled we must clean upgrade-related state.
  function clearUpgradeStatus() internal {
    upgradePreparationActive = false;
    _upgradePreparationActivationTime = 0;
    _approvedUpgradeNoticePeriod = UPGRADE_NOTICE_PERIOD;
    emit NoticePeriodChange(_approvedUpgradeNoticePeriod);
    _upgradeStartTimestamp = 0;
    for (uint256 i = 0; i < securityCouncilMembers.length; ++i) {
      _securityCouncilApproves[i] = false;
    }
    _numberOfApprovalsFromSecurityCouncil = 0;
  }
}
