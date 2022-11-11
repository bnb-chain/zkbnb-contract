// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

import "./Governance.sol";
import "./AssetGovernance.sol";
import "./Proxy.sol";
import "./UpgradeGatekeeper.sol";
import "./UpgradeableMaster.sol";
import "./ZkBNB.sol";
import "./ZkBNBVerifier.sol";
import "./Config.sol";
import "./ZNSController.sol";

contract DeployFactory {
    Proxy governance;
    Proxy verifier;
    Proxy znsController;
    Proxy znsResolver;
    Proxy zkbnb;

    event Addresses(
        address governance,
        address assetGovernance,
        address verifier,
        address znsController,
        address znsResolver,
        address zkbnb,
        address gatekeeper
    );

    // This struct is used for avoiding StackTooDeep
    struct DeployedContractAddress {
        Governance governanceTarget;
        ZkBNBVerifier verifierTarget;
        ZkBNB zkbnbTarget;
        ZNSController znsControllerTarget;
        PublicResolver znsResolverTarget;
        address validator;
        address governor;
        address listingToken;
        address zns;
        address priceOracle;
        UpgradeableMaster upgradeableMaster;
    }
    struct AdditionalParams {
        bytes32 genesisAccountRoot;
        uint256 listingFee;
        uint16 listingCap;
        bytes32 baseNode;
    }

    /// @dev Doing development in constructor method costs lower gas fee,
    ///      giving us simplicity and atomicity of our deployment.
    constructor(
        address[] memory addrs,
        bytes32 _genesisAccountRoot,
        uint256 _listingFee,
        uint16 _listingCap,
        bytes32 _baseNode
    ) {
        // package all contract address to struct for avoiding StackTooDeep
        DeployedContractAddress memory contracts = DeployedContractAddress({
            governanceTarget: Governance(addrs[0]),
            verifierTarget: ZkBNBVerifier(addrs[1]),
            zkbnbTarget: ZkBNB(addrs[2]),
            znsControllerTarget: ZNSController(addrs[3]),
            znsResolverTarget: PublicResolver(addrs[4]),
            validator: addrs[5],
            governor: addrs[6],
            listingToken: addrs[7],
            zns: addrs[8],
            priceOracle: addrs[9],
            upgradeableMaster: UpgradeableMaster(addrs[10])
        });
        require(contracts.validator != address(0), "validator check");
        require(contracts.governor != address(0), "governor check");

        AdditionalParams memory params = AdditionalParams({
            genesisAccountRoot: _genesisAccountRoot,
            listingFee: _listingFee,
            listingCap: _listingCap,
            baseNode: _baseNode
        });

        deployProxyContracts(contracts, params);

        selfdestruct(msg.sender);
    }

    function deployProxyContracts(
        DeployedContractAddress memory _contracts,
        AdditionalParams memory _additionalParams
    ) internal {
        governance = new Proxy(
            address(_contracts.governanceTarget),
            abi.encode(this)
        );
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
        znsController = new Proxy(
            address(_contracts.znsControllerTarget),
            abi.encode(
                _contracts.zns,
                _contracts.priceOracle,
                _additionalParams.baseNode
            )
        );
        znsResolver = new Proxy(
            address(_contracts.znsResolverTarget),
            abi.encode(_contracts.zns)
        );
        AdditionalZkBNB additionalZkBNB = new AdditionalZkBNB();
        zkbnb = new Proxy(
            address(_contracts.zkbnbTarget),
            abi.encode(
                address(governance),
                address(verifier),
                address(additionalZkBNB),
                address(znsController),
                address(znsResolver),
                _additionalParams.genesisAccountRoot
            )
        );

        UpgradeGatekeeper upgradeGatekeeper = new UpgradeGatekeeper(
            _contracts.upgradeableMaster
        );

        governance.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(governance));

        verifier.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(verifier));

        znsController.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(znsController));

        znsResolver.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(znsResolver));

        zkbnb.transferMastership(address(upgradeGatekeeper));
        upgradeGatekeeper.addUpgradeable(address(zkbnb));

        upgradeGatekeeper.transferMastership(_contracts.governor);

        emit Addresses(
            address(governance),
            address(assetGovernance),
            address(verifier),
            address(znsController),
            address(znsResolver),
            address(zkbnb),
            address(upgradeGatekeeper)
        );

        // finally set governance
        finalizeGovernance(
            Governance(address(governance)),
            assetGovernance,
            _contracts.validator,
            _contracts.governor
        );
        finalizeZNSController(
            ZNSController(address(znsController)),
            address(zkbnb)
        );
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

    function finalizeZNSController(ZNSController _znsController, address _zkbnb)
        internal
    {
        _znsController.addController(_zkbnb);
        _znsController.transferOwnership(_zkbnb);
    }
}
