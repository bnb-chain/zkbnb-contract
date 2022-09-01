# Design of ZkBAS Contract 

## ZkBAS Key Contracts
### ZkBAS
#### commitBlocks
```
    function commitBlocks(
        StoredBlockInfo memory _lastCommittedBlockData,
        CommitBlockInfo[] memory _newBlocksData
    )
    external;
```
Validators commit blocks from L2 to L1 and the blocks will be stored on L1 for later validation.
Commit one block includes the following steps:

1. check `blockNumber`, `timestamp`
2. check if priority operations from the committed block are same as the transactions in `priority queue`. 
All onchain operations as below:  
    - `RegisterZNS`: register ZNS name 
    - `CreatePair`: create token pair for token swap on L2
    - `UpdatePairRate`: update fee rate of the token pair 
    - `Deposit`: deposit tokens from L1 to L2
    - `DepositNft`: deposit NFT from L1 to L2
    - `Withdraw`: withdraw tokens from L2 to L1, sending request to L2
    - `WithdrawNft`: withdraw NFT from L2 to L1, sending request to L2
    - `FullExit`: request exit tokens from L2 to L1, sending request to L1
    - `FullExitNft`: request exit NFT from L2 to L1, sending request to L1
3. create block commitment for verification proof
4. store block hash on chain

```
    struct CommitBlockInfo {
        bytes32 newStateRoot;
        bytes publicData;
        uint256 timestamp;
        uint32[] publicDataOffsets;
        uint32 blockNumber;
        uint16 blockSize;
    }
```
`CommitBlock` contains block information, transaction data and the state root after the transactions has been executed.
Block information contains `timestamp`, `blockNumber` and `blockSize`. 
L2 transactions are packed in `CommitBlockInfo.publicData`


#### verifyAndExecuteBlocks

```
    function verifyAndExecuteBlocks(VerifyAndExecuteBlockInfo[] memory _blocks, uint256[] memory _proofs) external;
    
    function verifyAndExecuteOneBlock(VerifyAndExecuteBlockInfo memory _block, uint32 _verifiedBlockIdx) internal;
```

`verifyAndExecuteOneBlock` verifies and executes stored blocks from `commitBlocks`,
 including the following steps:
- check if the provided block was committed from `commitBlocks` before and in correct order
- check if the pending onchain operations are correct
- execute onchain operations if needed.(`Withdraw`, `WithdrawNft`, `FullExit`, `FullExitNft`) 

#### registerZNS
```
    function registerZNS(string calldata _name, address _owner, bytes32 _ZkBASPubKeyX, bytes32 _ZkBASPubKeyY) external payable;
```
Add request that registering a ZNS name into `priority queue`.

#### depositBNB
```
    function depositBNB(string calldata _accountName) external payable;
```
Deposit native asset to L2, `_accountName` will receive the BNB on L2. This function including the following steps:
- transfer BNB from user into `ZkBAS` contract
- add `Deposit` request into `priority queue`

#### depositBEP20
```
    function depositBEP20(
        IERC20 _token,
        uint104 _amount,
        string calldata _accountName
    ) external;
```
Deposit BEP20 token to L2, `_accountName` will receive the token. This function including the following steps:
- transfer BEP20 token from user into `ZkBAS` contract
- check if the token is allowed to deposit to L2
- add `Deposit` request into `priority queue`

#### view functions
```
    function getAddressByAccountNameHash(bytes32 accountNameHash) public view returns (address);

    function isRegisteredZNSName(string memory name) external view returns (bool);

    function getZNSNamePrice(string calldata name) external view returns (uint256);
    
    function getNFTFactory(bytes32 _creatorAccountNameHash, uint32 _collectionId) public view returns (address);
    
    function getPendingBalance(address _address, address _assetAddr) public view returns (uint128);
```
`ZkBAS` provides some interfaces to query L1 and L2 status.
- `getAddressByAccountNameHash`: 
- `isRegisteredZNSName`: check if the provided ZNS name is registered
- `getZNSNamePrice`: get the price of the provided ZNS name
- `getNFTFactory`: get a registered NFTFactory according to the creator accountNameHash and the collectionId
- `getPendingBalance`: get pending balance that the user can withdraw


### AdditionalZkBAS

Due to a ceiling on the code size of `ZkBAS` contract, `AdditionalZkBAS` will store more logic code which could not be stored on `ZkBAS`.

#### createPair
```
    function createPair(address _tokenA, address _tokenB) external;
```

Create token pair for token swap on L2. This function including the following steps:

- check if the pair of provided tokens already exists and the provided tokens are allowed to create pair on L2
- If caller is not present in the `tokenLister` map, payment of `listingFee` in `listingFeeToken` should be made
- record new token pair on chain
- add `CreatePair` request into `priority queue`

#### updatePairRate
```
    function updatePairRate(PairInfo memory _pairInfo) external;
```

Update the fee rate of provided pair on L2. This function including the following steps:
- check if the pair exists and tokens are allowed to update fee rate
- update token pair fee rate on L1
- add `UpdatePairRate` request into `priority queue`

### AssetGovernance
`AssetGovernance` contract is used to allow anyone to add new ERC20 tokens to ZkBAS given sufficient payment.

#### addAsset
```
    function addAsset(address _assetAddress) external;
```
This function allows anyone adds new ERC20 token to ZkBAS network.
If caller is not present in the `tokenLister` map, payment of `listingFee` in `listingFeeToken` should be made.
before calling this function make sure to approve `listingFeeToken` transfer for this contract.

### ZkBASVerifier
`ZkBASVerifier` contract help `ZkBAS` to verify the committed blocks and proofs.

#### verifyBatchProofs
```
    function verifyBatchProofs(
        uint256[] memory in_proof, // proof itself, length is 8 * num_proofs
        uint256[] memory proof_inputs, // public inputs, length is num_inputs * num_proofs
        uint256 num_proofs,
        uint16 block_size
    )
    public
    view
    returns (bool success);
    
    function verifyProof(
        uint256[] memory in_proof,
        uint256[] memory proof_inputs,
        uint16 block_size
    )
    public
    view
    returns (bool);
```

This function allows verifying batch proofs for batch blocks.

## ZkBAS Name Service

ZkBAS Name Service(ZNS) is a name service between L1 and L2. Users should register name in L1 
and set his L2 account address(Bytes32 public key) with this name. So that this user can use this name
both in L1 and L2.

Names are stored as node in contracts. Each node is mapped by a byte32 name hash. 
The name hash can be calculated as below(a Javascript implementation is in ./test/zns-registry.js):

#### namehash
```python
def namehash(name):
  if name == '':
    return '\0' * 32
  else:
    label, _, remainder = name.partition('.')
    return sha3(namehash(remainder) + sha3(label))
```

Note that each legal name should only contain lower-case character and number with a length between 3-32(included).

Contracts of ZNS are consists of three parts: ZNSRegistry, ZNSRegistrarController and ZNSResolver.

### ZNSRegistry

A ZNSRegistry contains records of name node. It will be owned as a member variable by ZNSRegistrarController.

All ZNS lookups start by querying the registry. The registry contains records of ZkBAS short name, recording the
owner, L2 owner and resolver of each name, and allows the owner of a domain to make changes to these data.

#### ZNS.sol

Interface of the ZNS Registry.

It defines events:

1. NewOwner: Logged when the owner of a node assigns a new owner to a subnode.
2. NewL2Owner: Logged when the L2 owner of a node transfers ownership to a new L2 account.
3. NewResolver: Logged when the resolver for a node changes.

These events can be monitored by BlockMonitor service.

It also defines setter and getter function of member variables in ZNSRecord.

#### ZNSRegistry.sol

Implementation of ZNS.sol.

It defines a struct Record contains: owner, L2Owner(public key) and resolver of a name.

#### Record
```go
struct Record {
    // The owner of a record may:
    // 1. Transfer ownership of the name to another address
    // 2. Change the ownership of sub account name
    // 3. Change the L2 owner of this account name
    // 4. Set the ttl and resolver of node
	address owner;
	bytes32 pubKey;
	address resolver;
}
```

Setter and Getter methods of each field is defined in this registry.

All short names are maintained by this contract and each name is mapped to a Record.

### ZNSRegistrarController

#### ZNSRegistrarController.sol

It provides external functions for users to register (and transfer) ZkBAS names.

It also maintains a mapper from L2Account to node's name hash, which can be used to assure
each L2 account can only own one name.

It defines external methods:
1. register: register a not existed name for a specified address, which actually invokes safeMint to mint a name node nft.

### ZNSResolver

A resolver is used to resolve detailed information of a name in L1, like a text, public key 
connected with this node.

An external contract should implement the `Resolver.sol` and the owner of nodes can set this contract 
as the resolver for his nodes. Then others can resolve this name for detailed information by calling this external contract.


## Upgradeable Design
Contracts deployed using `DeployFactory` can be upgraded to modify their code, while preserving their address, state, and balance.
This allows you to iteratively add new features to your contracts, or fix any bugs after deployed.
`DeployFactory` deploy a proxy to the implementation contract, which is the contract that you actually interact with.

Upgradeable contracts:
- `Governance`
- `ZkBASVerifier`
- `ZNSController`
- `PublicResolver`
- `ZkBAS`

There are several phases to the upgrade process:

1. `startUpgrade`: start upgrade process, stored the new target implementations on `nextTargets` and noticed the community
    - `UpgradeStatus.Idle` => `UpgradeStatus.NoticePeriod`

2. `startPreparation`:  activates preparation status to be ready for upgrade
    - `UpgradeStatus.NoticePeriod` => `UpgradeStatus.Preparation`

3. `finishUpgrade`:  finishes the upgrade
    - `UpgradeStatus.Preparation` => `UpgradeStatus.Idle`

### DeployFactory
```
    function deployProxyContracts(
        Governance _governanceTarget,
        ZkBASVerifier _verifierTarget,
        ZkBAS _ZkBASTarget,
        ZNSController _znsControllerTarget,
        PublicResolver _znsResolverTarget,
        AdditionalParams memory _additionalParams
    ) internal;
```
This function deploy proxies for upgradeable contracts in `ZkBAS`.

### UpgradeGatekeeper
`UpgradeGatekeeper` is the admin contract who will be the only one allowed to manage and upgrade these upgradeable contracts.

#### managedContracts
```
    Upgradeable[] public managedContracts;

    enum UpgradeStatus {
        Idle,
        NoticePeriod,
        Preparation
    }
    
    UpgradeStatus public upgradeStatus;
```
`managedContracts` stores upgradeable contracts managed by `UpgradeGatekeeper`.
`upgradeStatus` stores the status of all upgrades.
All upgradeable contracts can only remain in the same state if already started upgrade.

#### addUpgradeable
```
    function addUpgradeable(address addr) external;
```
This function adds a new upgradeable contract to the list of contracts managed by the `UpgradeGatekeeper`.

#### startUpgrade
```
    function startUpgrade(address[] calldata newTargets) external;
```
This function starts upgrade for the contracts corresponding to `newTargets` (activates notice period)

#### cancelUpgrade
```
    function cancelUpgrade() external;
```
This function cancels upgrade process only at the period of `UpgradeStatus.NoticePeriod` and `UpgradeStatus.Preparation`.


#### startPreparation
```
    function startPreparation() external;
```
This function activates preparation status only at the period of `UpgradeStatus.NoticePeriod`.


#### finishUpgrade
```
    function finishUpgrade() external;
```
This function finishes upgrades only at the period of `UpgradeStatus.Preparation`, setting new target implementations stored before to proxies.


### Proxy
```
interface Upgradeable {
    /// @notice Upgrades target of upgradeable contract
    /// @param newTarget New target
    /// @param newTargetInitializationParameters New target initialization parameters
    function upgradeTarget(address newTarget, bytes calldata newTargetInitializationParameters) external;
}

interface UpgradeableMaster {
    /// @notice Notice period before activation preparation status of upgrade mode
    function getNoticePeriod() external returns (uint256);

    /// @notice Notifies contract that notice period started
    function upgradeNoticePeriodStarted() external;

    /// @notice Notifies contract that upgrade preparation status is activated
    function upgradePreparationStarted() external;

    /// @notice Notifies contract that upgrade canceled
    function upgradeCanceled() external;

    /// @notice Notifies contract that upgrade finishes
    function upgradeFinishes() external;

    /// @notice Checks that contract is ready for upgrade
    /// @return bool flag indicating that contract is ready for upgrade
    function isReadyForUpgrade() external returns (bool);
}
```
All proxies of upgradeable contracts should implement `Upgradeable` and `UpgradeableMaster` interface for management of `UpgradeGatekeeper`.
