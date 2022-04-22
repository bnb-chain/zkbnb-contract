// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

import "./Governance.sol";
import "./AssetGovernance.sol";
import "./Proxy.sol";
import "./UpgradeGatekeeper.sol";
import "./ZecreyLegend.sol";
import "./ZecreyVerifier.sol";
import "./Config.sol";

contract DeployFactory {
    Proxy config;
    Proxy governance;
    Proxy assetGovernance;
    Proxy verifier;
    Proxy zecrey;

    function initConfig(
        Config _configTarget, uint8 _chainId,
        uint16 _nativeAssetId,
        uint16 _maxPendingBlocks
    ) external {
        config = new Proxy(address(_configTarget), abi.encode(_chainId, _nativeAssetId, _maxPendingBlocks));
    }

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
        governance = new Proxy(address(_govTarget), abi.encode(_governor, config));
    }

    function initVerifier(
        ZecreyVerifier _verifierTarget
    ) external {
        verifier = new Proxy(address(_verifierTarget), abi.encode());
    }

    function initZecrey(
        Zecrey _zecreyTarget,
        uint32 _genesisBlockNumber,
        bytes32 _genesisOnchainOpsRoot,
        bytes32 _genesisStateRoot,
        uint256 _genesisTimestamp,
        bytes32 _genesisCommitment,
        bool[6] memory _onchainOpsHelper,
        address _committer,
        address _verifier,
        address _executor,
        address _monitor,
        address _governor
    ) external {
        require(_committer != address(0), "committer check");
        require(_verifier != address(0), "verifier check");
        require(_executor != address(0), "executor check");
        require(_monitor != address(0), "monitor check");
        require(_governor != address(0), "governor check");
        zecrey = new Proxy(
            address(_zecreyTarget),
            abi.encode(address(config), address(governance), address(verifier),
            _genesisBlockNumber, _genesisOnchainOpsRoot, _genesisStateRoot, _genesisTimestamp, _genesisCommitment, _onchainOpsHelper)
        );
    }

    event Addresses(address config, address governance, address assetGovernance, address zecrey, address verifier, address gatekeeper);

    function deployProxyContracts(
        address _validator,
        address _governor
    ) external {

        UpgradeGatekeeper upgradeGatekeeper = new UpgradeGatekeeper(zecrey, msg.sender);

        config.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(config));

        governance.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(governance));

        assetGovernance.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(assetGovernance));

        verifier.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(verifier));

        zecrey.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(zecrey));

        upgradeGatekeeper.transferMastership(_governor);

        emit Addresses(address(config), address(governance), address(assetGovernance), address(zecrey), address(verifier), address(upgradeGatekeeper));

        finalizeGovernance(Governance(address(governance)), address(assetGovernance), _validator);

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
}
