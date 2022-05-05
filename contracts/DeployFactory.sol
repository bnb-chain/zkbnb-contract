// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

import "./Governance.sol";
import "./AssetGovernance.sol";
import "./Proxy.sol";
import "./UpgradeGatekeeper.sol";
import "./ZecreyLegend.sol";
import "./ZecreyVerifier.sol";
import "./Config.sol";
import "./ZNSController.sol";

contract DeployFactory {
    Proxy governance;
    Proxy assetGovernance;
    Proxy verifier;
    Proxy znsFifsRegistrar;
    Proxy additionalZecreyLegend;
    Proxy zecrey;

    function initAssetGovernance(
        AssetGovernance _assetGovTarget,
        address _governance,
        address _listingToken,
        uint256 _listingFee,
        uint16 _listingCap,
        address _governor
    ) external {
        assetGovernance = new Proxy(address(_assetGovTarget), abi.encode(_governance, _listingToken, _listingFee, _listingCap, _governor));
    }

    function initGovernance(
        Governance _govTarget,
        address _governor
    ) external {
        governance = new Proxy(address(_govTarget), abi.encode(_governor));
    }

    function initVerifier(
        ZecreyVerifier _verifierTarget
    ) external {
        verifier = new Proxy(address(_verifierTarget), abi.encode());
    }

    function initZnsFifsRegistrar(
        ZNSController _znsFifsRegistrar,
        address _zns,
        bytes32 _node
    ) external {
        znsFifsRegistrar = new Proxy(address(_znsFifsRegistrar), abi.encode(_zns, _node));
    }

    function initAdditionalZecreyLegend(
        AdditionalZecreyLegend _additionalZecreyLegend
    ) external {
        additionalZecreyLegend = new Proxy(address(_additionalZecreyLegend), abi.encode());
    }


    function initZecrey(
        ZecreyLegend _zecreyTarget,
        bytes32 _genesisAccountRoot,
        address _validator,
        address _governor
    ) external {
        require(_validator != address(0), "committer check");
        require(_governor != address(0), "governor check");
        zecrey = new Proxy(
            address(_zecreyTarget),
            abi.encode(address(governance), address(verifier), address(additionalZecreyLegend), address(znsFifsRegistrar),
            _genesisAccountRoot)
        );
    }

    event Addresses(address governance, address assetGovernance, address verifier, address znsFifsRegistrar, address additionalZecreyLegend, address zecrey, address gatekeeper);

    function deployProxyContracts(
        address _validator,
        address _governor
    ) external {
        // TODO Change msg.sender to this contract
        UpgradeGatekeeper upgradeGatekeeper = new UpgradeGatekeeper(zecrey, msg.sender);

        governance.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(governance));

        assetGovernance.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(assetGovernance));

        verifier.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(verifier));

        znsFifsRegistrar.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(znsFifsRegistrar));

        additionalZecreyLegend.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(additionalZecreyLegend));

        zecrey.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(zecrey));

        upgradeGatekeeper.transferMastership(_governor);

        emit Addresses(address(governance), address(assetGovernance), address(verifier), address(znsFifsRegistrar),
            address(additionalZecreyLegend), address(zecrey), address(upgradeGatekeeper));

        finalizeGovernance(Governance(address(governance)), address(assetGovernance), _validator);
        finalizeZnsFifsRegistrar(ZNSController(address(znsFifsRegistrar)), address(zecrey));
        // TODO

        selfdestruct(payable(address(this)));
    }

    function finalizeGovernance(
        Governance _governance,
        address _assetGovernance,
        address _validator
    ) internal {
        _governance.changeAssetGovernance(AssetGovernance(_assetGovernance));
        _governance.setValidator(_validator, true);
    }

    function finalizeZnsFifsRegistrar(
        ZNSController _znsFifsRegistrar,
        address _zecrey
    ) internal {
        _znsFifsRegistrar.addController(_zecrey);
    }
}
