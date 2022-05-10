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
    Proxy verifier;
    Proxy znsController;
    Proxy znsResolver;
    Proxy zecreyLegend;

    /// @dev Doing development in constructor method costs lower gas fee,
    ///      giving us simplicity and atomicity of our deployment.
    constructor(
        Governance _governanceTarget,
        ZecreyVerifier _verifierTarget,
        ZecreyLegend _zecreyLegendTarget,
        ZNSController _znsControllerTarget,
        PublicResolver _znsResolverTarget,
        bytes32 _genesisAccountRoot,
        address _validator,
        address _governor,
        address _listingToken,
        uint256 _listingFee,
        uint16 _listingCap,
        address _zns,
        bytes32 _baseNode
    ) {
        require(_validator != address(0), "validator check");
        require(_governor != address(0), "governor check");

        deployProxyContracts(
            _governanceTarget,
            _verifierTarget,
            _zecreyLegendTarget,
            _znsControllerTarget,
            _znsResolverTarget,
            _genesisAccountRoot,
            _validator,
            _governor,
            _listingToken,
            _listingFee,
            _listingCap,
            _zns,
            _baseNode
        );

        selfdestruct(msg.sender);
    }

    event Addresses(address governance, address assetGovernance, address verifier, address znsController, address znsResolver, address zecreyLegend, address gatekeeper);

    function deployProxyContracts(
        Governance _governanceTarget,
        ZecreyVerifier _verifierTarget,
        ZecreyLegend _zecreyLegendTarget,
        ZNSController _znsControllerTarget,
        PublicResolver _znsResolverTarget,
        bytes32 _genesisAccountRoot,
        address _validator,
        address _governor,
        address _listingToken,
        uint256 _listingFee,
        uint16 _listingCap,
        address _zns,
        bytes32 _baseNode
    ) internal {
        governance = new Proxy(address(_governanceTarget), abi.encode(this)); // Here temporarily give this contract the governor right.
        AssetGovernance assetGovernance = new AssetGovernance(address(governance), _listingToken, _listingFee, _listingCap, _governor);
        verifier = new Proxy(address(_verifierTarget), abi.encode());
        znsController = new Proxy(address(_znsControllerTarget), abi.encode(_zns, _baseNode));
        znsResolver = new Proxy(address(_znsResolverTarget), abi.encode(_zns));
        AdditionalZecreyLegend additionalZecreyLegend = new AdditionalZecreyLegend();
        zecreyLegend = new Proxy(
            address(_zecreyLegendTarget),
            abi.encode(address(governance), address(verifier), address(additionalZecreyLegend), address(znsController), address(znsResolver), _genesisAccountRoot));

        UpgradeGatekeeper upgradeGatekeeper = new UpgradeGatekeeper(zecreyLegend);

        governance.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(governance));

        verifier.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(verifier));

        znsController.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(znsController));

        znsResolver.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(znsResolver));

        zecreyLegend.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(zecreyLegend));

        upgradeGatekeeper.transferMastership(_governor);

        emit Addresses(address(governance), address(assetGovernance), address(verifier), address(znsController),
            address(znsResolver), address(zecreyLegend), address(upgradeGatekeeper));

        // finally set governance
        finalizeGovernance(Governance(address(governance)), assetGovernance, _validator, _governor);
        finalizeZNSController(ZNSController(address(znsController)), address(zecreyLegend));
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

    function finalizeZNSController(
        ZNSController _znsController,
        address _zecreyLegend
    ) internal {
        _znsController.addController(_zecreyLegend);
        _znsController.transferOwnership(_zecreyLegend);
    }
}
