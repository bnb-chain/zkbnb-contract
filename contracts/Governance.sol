// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./Config.sol";
import "./lib/Utils.sol";
import "./lib/Bytes.sol";
import "./AssetGovernance.sol";
import "./ZkBNBNFTFactory.sol";

/// @title Governance Contract
/// @author ZkBNB Team
contract Governance is Config, Initializable {
  /// @notice Address which will exercise governance over the network i.e. add tokens, change validator set, conduct upgrades
  address public networkGovernor;

  /// @notice Total number of BEP20 tokens registered in the network (excluding BNB, which is hardcoded as assetId = 0)
  uint16 public totalAssets;

  mapping(address => bool) public validators;

  /// @notice Paused tokens list, deposits are impossible to create for paused tokens
  mapping(uint16 => bool) public pausedAssets;

  mapping(address => uint16) public assetsList;
  mapping(uint16 => address) public assetAddresses;

  /// @notice Address that is authorized to add tokens to the Governance.
  AssetGovernance public assetGovernance;

  /// @notice NFT Creator account to factory address mapping
  /// @dev creator address => CollectionId => NFTFactory
  mapping(address => mapping(uint16 => address)) public nftFactories;

  /// @notice NFT factory address to creator address mapping
  mapping(address => address) public nftFactoryCreators;

  /// @notice NFT baseURI nftContentType to baseURI mapping
  mapping(uint8 => string) public nftBaseURIs;

  /// @notice Address which will be used if no factories is specified.
  address public defaultNFTFactory;

  /// @notice zkBNB contract address.
  address public zkBNBAddress;

  /// @notice Token added to Franklin net
  event NewAsset(address assetAddress, uint16 assetId);

  /// @notice Governor changed
  event NewGovernor(address newGovernor);

  /// @notice Token Governance changed
  event NewAssetGovernance(AssetGovernance newAssetGovernance);

  event ValidatorStatusUpdate(address validatorAddress, bool isActive);

  event AssetPausedUpdate(address token, bool paused);

  /// @notice New nft factory deployed
  event NFTFactoryDeployed(address indexed creator, address indexed factory);

  /// @notice New NFT factory registered
  event NFTFactoryRegistered(address indexed creator, address indexed factory, uint16 indexed collectionId);

  /// @notice Default nft factory has set
  event SetDefaultNFTFactory(address indexed factory);

  /// @notice ZkBNB address has set
  event SetZkBNB(address indexed zkBNBAddress);

  /// @notice Governance contract initialization. Can be external because Proxy contract intercepts illegal calls of this function.
  /// @param initializationParameters Encoded representation of initialization parameters:
  ///     _networkGovernor The address of network governor
  function initialize(bytes calldata initializationParameters) external initializer {
    address _networkGovernor = abi.decode(initializationParameters, (address));

    networkGovernor = _networkGovernor;

    // initialize nftBaseURIs
    nftBaseURIs[0] = "ipfs://f01701220";
  }

  /// @notice Governance contract upgrade. Can be external because Proxy contract intercepts illegal calls of this function.
  /// @param upgradeParameters Encoded representation of upgrade parameters
  // solhint-disable-next-line no-empty-blocks
  function upgrade(bytes calldata upgradeParameters) external {}

  /// @notice Change current governor
  /// @param _newGovernor Address of the new governor
  function changeGovernor(address _newGovernor) external onlyGovernor {
    if (networkGovernor != _newGovernor) {
      networkGovernor = _newGovernor;
      emit NewGovernor(_newGovernor);
    }
  }

  function changeAssetGovernance(AssetGovernance _newAssetGovernance) external onlyGovernor {
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

    ++totalAssets;
    uint16 newAssetId = totalAssets;
    // it is not `totalTokens - 1` because tokenId = 0 is reserved for BNB

    assetAddresses[newAssetId] = _asset;
    assetsList[_asset] = newAssetId;

    if (newAssetId > 1) {
      // 0 => BNB,  1 => BUSD
      emit NewAsset(_asset, newAssetId);
    }
  }

  function setAssetPaused(address _assetAddress, bool _assetPaused) external onlyGovernor {
    uint16 assetId = assetsList[_assetAddress];
    require(assetId != 0, "1i");

    if (pausedAssets[assetId] != _assetPaused) {
      pausedAssets[assetId] = _assetPaused;
      emit AssetPausedUpdate(_assetAddress, _assetPaused);
    }
  }

  function setValidator(address _validator, bool _active) external onlyGovernor {
    if (validators[_validator] != _active) {
      validators[_validator] = _active;
      emit ValidatorStatusUpdate(_validator, _active);
    }
  }

  function isActiveValidator(address _address) external view {
    require(validators[_address], "invalid validator");
  }

  function validateAssetAddress(address _assetAddr) external view returns (uint16) {
    uint16 assetId = assetsList[_assetAddr];
    require(assetId != 0, "1i");
    require(!pausedAssets[assetId], "2i");
    return assetId;
  }

  /// @notice Check if specified address is governor
  /// @param _address Address to check
  function requireGovernor(address _address) public view {
    require(_address == networkGovernor, "1g");
    // only by governor
  }

  /// @notice Check if specified address is governor
  modifier onlyGovernor() {
    require(msg.sender == networkGovernor, "1g");
    _;
  }

  /// @notice Register collection corresponding to the default factory
  /// @param _creatorAddress L2 collection creator address
  /// @param _collectionId L2 collection id
  function registerDefaultNFTFactory(address _creatorAddress, uint16 _collectionId) external {
    require(msg.sender == zkBNBAddress, "No access");
    if (nftFactories[_creatorAddress][_collectionId] == address(0)) {
      nftFactories[_creatorAddress][_collectionId] = defaultNFTFactory;
    }
  }

  /// @notice Register collection corresponding to the factory
  /// @param _collectionId L2 collection id
  /// @param _factoryAddress NFT factor address
  function registerNFTFactory(uint16 _collectionId, address _factoryAddress) public {
    require(nftFactories[msg.sender][_collectionId] == address(0), "Q");
    require(nftFactoryCreators[_factoryAddress] == msg.sender, "ws");
    nftFactories[msg.sender][_collectionId] = _factoryAddress;
    emit NFTFactoryRegistered(msg.sender, _factoryAddress, _collectionId);
  }

  /// @notice Deploy and register collection corresponding to the factory
  /// @param _collectionId L2 collection id
  /// @param _name NFT factory name
  /// @param _symbol NFT factory symbol
  function deployAndRegisterNFTFactory(uint16 _collectionId, string memory _name, string memory _symbol) external {
    require(zkBNBAddress != address(0), "ZkBNB address does not set");
    ZkBNBNFTFactory _factory = new ZkBNBNFTFactory(_name, _symbol, zkBNBAddress, msg.sender);
    address _factoryAddress = address(_factory);
    nftFactoryCreators[_factoryAddress] = msg.sender;
    emit NFTFactoryDeployed(msg.sender, _factoryAddress);
    registerNFTFactory(_collectionId, _factoryAddress);
  }

  /// @notice Set ZkBNB address
  /// @param _zkBNBAddress ZkBNB address
  function setZkBNBAddress(address _zkBNBAddress) external onlyGovernor {
    require(_zkBNBAddress != address(0), "Invalid address");
    require(zkBNBAddress != _zkBNBAddress, "Unchanged");
    zkBNBAddress = _zkBNBAddress;
    emit SetZkBNB(_zkBNBAddress);
  }

  /// @notice Set default factory for our contract. This factory will be used to mint an NFT token that has no factory
  /// @param _factoryAddress Address of NFT factory
  function setDefaultNFTFactory(address _factoryAddress) external onlyGovernor {
    require(_factoryAddress != address(0), "mb1"); // Factory should be non zero
    require(defaultNFTFactory == address(0), "mb2"); // NFTFactory is already set
    defaultNFTFactory = _factoryAddress;
    emit SetDefaultNFTFactory(_factoryAddress);
  }

  /// @notice Get a registered NFTFactory according to the creator address and the collectionId
  /// @param _creatorAddress creator account address
  /// @param _collectionId collection id of the nft collection related to this creator
  function getNFTFactory(address _creatorAddress, uint16 _collectionId) external view returns (address) {
    address _factory = nftFactories[_creatorAddress][_collectionId];
    // Use the default factory when the collection is not bound a factory
    if (_factory == address(0)) {
      require(defaultNFTFactory != address(0), "fs"); // NFTFactory does not set
      return defaultNFTFactory;
    } else {
      return _factory;
    }
  }

  /// @notice update nftBaseURIs mapping
  /// @param nftContentType which protocol to store nft content
  /// @param baseURI nft baseURI, used to generate tokenURI of nft
  function updateBaseURI(uint8 nftContentType, string memory baseURI) external onlyGovernor {
    nftBaseURIs[nftContentType] = baseURI;
  }

  /// @notice uery the tokenURI by nftContentType and nftContentHash
  /// @param nftContentType which protocol to store nft content
  /// @param nftContentHash hash of nft content
  function getNftTokenURI(uint8 nftContentType, bytes32 nftContentHash) external view returns (string memory tokenURI) {
    if (nftContentType == 0) {
      tokenURI = string(abi.encodePacked("ipfs://", Utils.ipfsCID(nftContentHash)));
    } else {
      tokenURI = string(abi.encodePacked(nftBaseURIs[nftContentType], Bytes.bytes32ToHexString(nftContentHash, false)));
    }
  }
}
