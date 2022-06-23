// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Governance.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Utils.sol";

/// @title Asset Governance Contract
/// @author Zkbas Team
/// @notice Contract is used to allow anyone to add new ERC20 tokens to Zkbas given sufficient payment
contract AssetGovernance is ReentrancyGuard {
    /// @notice Token lister added or removed (see `tokenLister`)
    event TokenListerUpdate(address indexed tokenLister, bool isActive);

    /// @notice Listing fee token set
    event ListingFeeTokenUpdate(IERC20 indexed newListingFeeToken, uint256 newListingFee);

    /// @notice Listing fee set
    event ListingFeeUpdate(uint256 newListingFee);

    /// @notice Maximum number of listed tokens updated
    event ListingCapUpdate(uint16 newListingCap);

    /// @notice The treasury (the account which will receive the fee) was updated
    event TreasuryUpdate(address newTreasury);

    /// @notice The treasury account index was updated
    event TreasuryAccountIndexUpdate(uint32 _newTreasuryAccountIndex);

    /// @notice The treasury fee rate was updated
    event TreasuryRateUpdate(uint16 _newTreasuryRate);

    /// @notice The fee rate was updated
    event FeeRateUpdate(uint16 _newFeeRate);

    /// @notice Zkbas governance contract
    Governance public governance;

    /// @notice Token used to collect listing fee for addition of new token to Zkbas network
    IERC20 public listingFeeToken;

    /// @notice Token listing fee
    uint256 public listingFee;

    /// @notice Max number of tokens that can be listed using this contract
    uint16 public listingCap;

    /// @notice Addresses that can list tokens without fee
    mapping(address => bool) public tokenLister;

    /// @notice Address that collects listing payments
    address public treasury;

    /// @notice AccountIndex that collects listing payments
    uint32 public treasuryAccountIndex;

    /// @notice Fee rate when exchange token pair
    uint16 public feeRate;

    /// @notice Treasury fee rate when exchange token pair
    uint16 public treasuryRate;

    constructor (
        address _governance,
        address _listingFeeToken,
        uint256 _listingFee,
        uint16 _listingCap,
        address _treasury,
        uint16 _feeRate,
        uint32 _treasuryAccountIndex,
        uint16 _treasuryRate
    ) {

        governance = Governance(_governance);
        listingFeeToken = IERC20(_listingFeeToken);
        listingFee = _listingFee;
        listingCap = _listingCap;
        treasury = _treasury;
        treasuryAccountIndex = _treasuryAccountIndex;
        feeRate = _feeRate;
        treasuryRate = _treasuryRate;
        // We add treasury as the first token lister
        tokenLister[treasury] = true;
        emit TokenListerUpdate(treasury, true);
    }

    /// @notice Governance contract upgrade. Can be external because Proxy contract intercepts illegal calls of this function.
    /// @param upgradeParameters Encoded representation of upgrade parameters
    // solhint-disable-next-line no-empty-blocks
    function upgrade(bytes calldata upgradeParameters) external {}

    /// @notice Adds new ERC20 token to Zkbas network.
    /// @notice If caller is not present in the `tokenLister` map, payment of `listingFee` in `listingFeeToken` should be made.
    /// @notice NOTE: before calling this function make sure to approve `listingFeeToken` transfer for this contract.
    function addAsset(address _assetAddress) external {
        require(governance.totalAssets() < listingCap, "can't add more tokens");
        // Impossible to add more tokens using this contract
        if (!tokenLister[msg.sender]) {
            // Collect fees
            bool feeTransferOk = Utils.transferFromERC20(listingFeeToken, msg.sender, treasury, listingFee);
            require(feeTransferOk, "fee transfer failed");
            // Failed to receive payment for token addition.
        }
        governance.addAsset(_assetAddress);
    }

    /// Governance functions (this contract is governed by Zkbas governor)

    /// @notice Set new listing token and fee
    /// @notice Can be called only by Zkbas governor
    function setListingFeeAsset(IERC20 _newListingFeeAsset, uint256 _newListingFee) external {
        governance.requireGovernor(msg.sender);
        listingFeeToken = _newListingFeeAsset;
        listingFee = _newListingFee;

        emit ListingFeeTokenUpdate(_newListingFeeAsset, _newListingFee);
    }

    /// @notice Set new listing fee
    /// @notice Can be called only by Zkbas governor
    function setListingFee(uint256 _newListingFee) external {
        governance.requireGovernor(msg.sender);
        listingFee = _newListingFee;

        emit ListingFeeUpdate(_newListingFee);
    }

    /// @notice Enable or disable token lister. If enabled new tokens can be added by that address without payment
    /// @notice Can be called only by Zkbas governor
    function setLister(address _listerAddress, bool _active) external {
        governance.requireGovernor(msg.sender);
        if (tokenLister[_listerAddress] != _active) {
            tokenLister[_listerAddress] = _active;
            emit TokenListerUpdate(_listerAddress, _active);
        }
    }

    /// @notice Change maximum amount of tokens that can be listed using this method
    /// @notice Can be called only by Zkbas governor
    function setListingCap(uint16 _newListingCap) external {
        governance.requireGovernor(msg.sender);
        listingCap = _newListingCap;

        emit ListingCapUpdate(_newListingCap);
    }

    /// @notice Change address that collects payments for listing tokens.
    /// @notice Can be called only by Zkbas governor
    function setTreasury(address _newTreasury) external {
        governance.requireGovernor(msg.sender);
        treasury = _newTreasury;

        emit TreasuryUpdate(_newTreasury);
    }

    /// @notice Change account index that collects payments for listing tokens.
    /// @notice Can be called only by Zkbas governor
    function setTreasuryAccountIndex(uint32 _newTreasuryAccountIndex) external {
        governance.requireGovernor(msg.sender);
        treasuryAccountIndex = _newTreasuryAccountIndex;

        emit TreasuryAccountIndexUpdate(_newTreasuryAccountIndex);
    }

    /// @notice Change treasury fee rate
    /// @notice Can be called only by Zkbas governor
    function setTreasuryRate(uint16 _newTreasuryRate) external {
        governance.requireGovernor(msg.sender);
        treasuryRate = _newTreasuryRate;

        emit TreasuryRateUpdate(_newTreasuryRate);
    }

    /// @notice Change fee rate
    /// @notice Can be called only by Zkbas governor
    function setFeeRate(uint16 _newFeeRate) external {
        governance.requireGovernor(msg.sender);
        feeRate = _newFeeRate;

        emit FeeRateUpdate(_newFeeRate);
    }
}
