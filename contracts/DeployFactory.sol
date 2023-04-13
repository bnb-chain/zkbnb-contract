// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./Governance.sol";
import "./AssetGovernance.sol";
import "./Proxy.sol";
import "./UpgradeGatekeeper.sol";
import "./UpgradeableMaster.sol";
import "./ZkBNB.sol";
import "./ZkBNBVerifier.sol";
import "./Config.sol";

contract DeployFactory {
  // This struct is used for avoiding StackTooDeep
  struct DeployedContractAddress {
    Governance governanceTarget;
    ZkBNBVerifier verifierTarget;
    ZkBNB zkbnbTarget;
    address validator;
    address governor;
    address listingToken;
    address desertVerifier;
    UpgradeableMaster upgradeableMaster;
  }

  struct AdditionalParams {
    bytes32 genesisAccountRoot;
    uint256 listingFee;
    uint16 listingCap;
  }

  Proxy governance;
  Proxy verifier;
  Proxy zkbnb;

  event Addresses(
    address governance,
    address assetGovernance,
    address verifier,
    address zkbnb,
    address gatekeeper,
    address additionalZkBNB
  );

  /// @dev Doing development in constructor method costs lower gas fee,
  ///      giving us simplicity and atomicity of our deployment.
  constructor(address[] memory addrs, bytes32 _genesisAccountRoot, uint256 _listingFee, uint16 _listingCap) {
    // package all contract address to struct for avoiding StackTooDeep
    DeployedContractAddress memory contracts = DeployedContractAddress({
      governanceTarget: Governance(addrs[0]),
      verifierTarget: ZkBNBVerifier(addrs[1]),
      zkbnbTarget: ZkBNB(addrs[2]),
      validator: addrs[3],
      governor: addrs[4],
      listingToken: addrs[5],
      desertVerifier: addrs[6],
      upgradeableMaster: UpgradeableMaster(addrs[7])
    });
    require(contracts.validator != address(0), "validator check");
    require(contracts.governor != address(0), "governor check");

    AdditionalParams memory params = AdditionalParams({
      genesisAccountRoot: _genesisAccountRoot,
      listingFee: _listingFee,
      listingCap: _listingCap
    });

    deployProxyContracts(contracts, params);

    selfdestruct(payable(msg.sender));
  }

  function deployProxyContracts(
    DeployedContractAddress memory _contracts,
    AdditionalParams memory _additionalParams
  ) internal {
    governance = new Proxy(address(_contracts.governanceTarget), abi.encode(this));
    // Here temporarily give this contract the governor right.
    // TODO treasury rate
    AssetGovernance assetGovernance = new AssetGovernance(
      address(governance),
      _contracts.listingToken,
      _additionalParams.listingFee,
      _additionalParams.listingCap,
      _contracts.governor,
      0
    );
    verifier = new Proxy(address(_contracts.verifierTarget), abi.encode());
    AdditionalZkBNB additionalZkBNB = new AdditionalZkBNB();
    zkbnb = new Proxy(
      address(_contracts.zkbnbTarget),
      abi.encode(
        address(governance),
        address(verifier),
        address(additionalZkBNB),
        address(_contracts.desertVerifier),
        _additionalParams.genesisAccountRoot
      )
    );

    UpgradeGatekeeper upgradeGatekeeper = new UpgradeGatekeeper(_contracts.upgradeableMaster);

    governance.transferMastership(address(upgradeGatekeeper));
    upgradeGatekeeper.addUpgradeable(address(governance));

    verifier.transferMastership(address(upgradeGatekeeper));
    upgradeGatekeeper.addUpgradeable(address(verifier));

    zkbnb.transferMastership(address(upgradeGatekeeper));
    upgradeGatekeeper.addUpgradeable(address(zkbnb));

    upgradeGatekeeper.transferMastership(_contracts.governor);

    emit Addresses(
      address(governance),
      address(assetGovernance),
      address(verifier),
      address(zkbnb),
      address(upgradeGatekeeper),
      address(additionalZkBNB)
    );

    // finally set governance
    finalizeGovernance(Governance(address(governance)), assetGovernance, _contracts.validator, _contracts.governor);
  }

  function finalizeGovernance(
    Governance _governance,
    AssetGovernance _assetGovernance,
    address _validator,
    address _governor
  ) internal {
    _governance.changeAssetGovernance(_assetGovernance);
    _governance.setValidator(_validator, true);
    _governance.changeGovernor(_governor);
  }
}
