// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Governance.sol";
import "./lib/Utils.sol";

/// @title Asset Governance Contract
/// @author ZkBNB Team
/// @notice Contract is used to allow anyone to add new ERC20 tokens to ZkBNB given sufficient payment
contract AssetGovernance is ReentrancyGuard {
  /// @notice ZkBNB governance contract
  Governance public governance;

  /// @notice Token used to collect listing fee for addition of new token to ZkBNB network
  IERC20 public listingFeeToken;

  /// @notice Token listing fee
  uint256 public listingFee;

  /// @notice Max number of tokens that can be listed using this contract
  uint16 public listingCap;

  /// @notice Addresses that can list tokens without fee
  mapping(address => bool) public tokenLister;

  /// @notice Address that collects listing payments
  address public treasury;

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

  constructor(
    address _governance,
    address _listingFeeToken,
    uint256 _listingFee,
    uint16 _listingCap,
    address _treasury,
    uint32 _treasuryAccountIndex
  ) {
    governance = Governance(_governance);
    listingFeeToken = IERC20(_listingFeeToken);
    listingFee = _listingFee;
    listingCap = _listingCap;
    treasury = _treasury;
    // We add treasury as the first token lister
    tokenLister[treasury] = true;
    emit TokenListerUpdate(treasury, true);
  }

  modifier onlyGovernor() {
    governance.requireGovernor(msg.sender);
    _;
  }

  /// @notice Adds new ERC20 token to ZkBNB network.
  /// @notice If caller is not present in the `tokenLister` map, payment of `listingFee` in `listingFeeToken` should be made.
  /// @notice NOTE: before calling this function make sure to approve `listingFeeToken` transfer for this contract.
  function addAsset(address _assetAddress) external nonReentrant {
    // Impossible to add more tokens using this contract
    require(governance.totalAssets() < listingCap, "can't add more tokens");
    if (!tokenLister[msg.sender]) {
      // Check access: if address zero is a lister, any address can add asset
      require(tokenLister[address(0)], "no access");
      // Collect fees
      listingFeeToken.transferFrom(msg.sender, treasury, listingFee);
    }
    governance.addAsset(_assetAddress);
  }

  /// Governance functions (this contract is governed by ZkBNB governor)

  /// @notice Set new listing token and fee
  /// @notice Can be called only by ZkBNB governor
  function setListingFeeAsset(IERC20 _newListingFeeAsset, uint256 _newListingFee) external onlyGovernor {
    listingFeeToken = _newListingFeeAsset;
    listingFee = _newListingFee;

    emit ListingFeeTokenUpdate(_newListingFeeAsset, _newListingFee);
  }

  /// @notice Set new listing fee
  /// @notice Can be called only by ZkBNB governor
  function setListingFee(uint256 _newListingFee) external onlyGovernor {
    listingFee = _newListingFee;

    emit ListingFeeUpdate(_newListingFee);
  }

  /// @notice Enable or disable token lister. If enabled new tokens can be added by that address without payment
  /// @notice Can be called only by ZkBNB governor
  function setLister(address _listerAddress, bool _active) external onlyGovernor {
    if (tokenLister[_listerAddress] != _active) {
      tokenLister[_listerAddress] = _active;
      emit TokenListerUpdate(_listerAddress, _active);
    }
  }

  /// @notice Change maximum amount of tokens that can be listed using this method
  /// @notice Can be called only by ZkBNB governor
  function setListingCap(uint16 _newListingCap) external onlyGovernor {
    listingCap = _newListingCap;

    emit ListingCapUpdate(_newListingCap);
  }

  /// @notice Change address that collects payments for listing tokens.
  /// @notice Can be called only by ZkBNB governor
  function setTreasury(address _newTreasury) external onlyGovernor {
    treasury = _newTreasury;

    emit TreasuryUpdate(_newTreasury);
  }
}
