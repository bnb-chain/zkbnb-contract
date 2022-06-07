// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

import "./Config.sol";
import "./Utils.sol";
import "./AssetGovernance.sol";
import "./SafeMathUInt32.sol";

/// @title Governance Contract
/// @author Zecrey Team
contract Governance is Config {

    /// @notice Token added to Franklin net
    event NewAsset(address assetAddress, uint16 assetId);

    /// @notice Governor changed
    event NewGovernor(address newGovernor);

    /// @notice Token Governance changed
    event NewAssetGovernance(AssetGovernance newAssetGovernance);

    event ValidatorStatusUpdate(address validatorAddress, bool isActive);

    event AssetPausedUpdate(address token, bool paused);

    /// @notice Address which will exercise governance over the network i.e. add tokens, change validator set, conduct upgrades
    address public networkGovernor;

    /// @notice Total number of ERC20 tokens registered in the network (excluding ETH, which is hardcoded as assetId = 0)
    uint16 public totalAssets;

    mapping(address => bool) public validators;

    /// @notice Paused tokens list, deposits are impossible to create for paused tokens
    mapping(uint16 => bool) public pausedAssets;

    mapping(address => uint16) public assetsList;
    mapping(uint16 => address) public assetAddresses;
    mapping(address => bool) public isAddressExists;

    /// @notice Address that is authorized to add tokens to the Governance.
    AssetGovernance public assetGovernance;

    /// @notice Governance contract initialization. Can be external because Proxy contract intercepts illegal calls of this function.
    /// @param initializationParameters Encoded representation of initialization parameters:
    ///     _networkGovernor The address of network governor
    function initialize(bytes calldata initializationParameters) external {
        address _networkGovernor = abi.decode(initializationParameters, (address));

        networkGovernor = _networkGovernor;
    }

    /// @notice Governance contract upgrade. Can be external because Proxy contract intercepts illegal calls of this function.
    /// @param upgradeParameters Encoded representation of upgrade parameters
    // solhint-disable-next-line no-empty-blocks
    function upgrade(bytes calldata upgradeParameters) external {}

    /// @notice Change current governor
    /// @param _newGovernor Address of the new governor
    function changeGovernor(address _newGovernor) external {
        requireGovernor(msg.sender);
        if (networkGovernor != _newGovernor) {
            networkGovernor = _newGovernor;
            emit NewGovernor(_newGovernor);
        }
    }

    function changeAssetGovernance(AssetGovernance _newAssetGovernance) external {
        requireGovernor(msg.sender);
        if (assetGovernance != _newAssetGovernance) {
            assetGovernance = _newAssetGovernance;
            emit NewAssetGovernance(_newAssetGovernance);
        }
    }

    /// @notice Add asset to the list of networks tokens
    /// @param _asset Token address
    function addAsset(address _asset) external {
        require(msg.sender == address(assetGovernance), "1E");
        require(assetsList[_asset] == 0, "1e");
        // token exists
        require(totalAssets < MAX_AMOUNT_OF_REGISTERED_ASSETS, "1f");
        // no free identifiers for tokens

        totalAssets++;
        uint16 newAssetId = totalAssets;
        // it is not `totalTokens - 1` because tokenId = 0 is reserved for eth

        assetAddresses[newAssetId] = _asset;
        assetsList[_asset] = newAssetId;
        emit NewAsset(_asset, newAssetId);
    }

    function setAssetPaused(address _assetAddress, bool _assetPaused) external {
        requireGovernor(msg.sender);

        uint16 assetId = this.validateAssetAddress(_assetAddress);
        if (pausedAssets[assetId] != _assetPaused) {
            pausedAssets[assetId] = _assetPaused;
            emit AssetPausedUpdate(_assetAddress, _assetPaused);
        }
    }

    function setValidator(address _validator, bool _active) external {
        requireGovernor(msg.sender);
        if (validators[_validator] != _active) {
            validators[_validator] = _active;
            emit ValidatorStatusUpdate(_validator, _active);
        }
    }

    /// @notice Check if specified address is governor
    /// @param _address Address to check
    function requireGovernor(address _address) public view {
        require(_address == networkGovernor, "1g");
        // only by governor
    }

    function requireActiveValidator(address _address) external view {
        require(validators[_address], "invalid validator");
    }

    function validateAssetAddress(address _assetAddr) external view returns (uint16) {
        uint16 assetId = assetsList[_assetAddr];
        require(assetId != 0, "1i");
        require(!pausedAssets[assetId], "2i");
        return assetId;
    }

    function validateAssetTokenLister(address _address) external {
        // If caller is not present in the `tokenLister` map, payment of `listingFee` in `listingFeeToken` should be made.
        if (!assetGovernance.tokenLister(_address)) {
            // Collect fees
            bool feeTransferOk = Utils.transferFromERC20(
                assetGovernance.listingFeeToken(),
                _address,
                assetGovernance.treasury(),
                assetGovernance.listingFee()
            );
            require(feeTransferOk, "fee transfer failed");
        }
    }
}
