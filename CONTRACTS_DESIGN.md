# Design of ZkBNB Contract 

## ZkBNB Key Contracts
### ZkBNB
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
    - `ChangePubKey`: changes public key of the account that is used to authorize transactions
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

#### depositBNB
```
    function depositBNB(address _to) external payable;
```
Deposit native asset to L2, `_to` will receive the BNB on L2. This function including the following steps:
- transfer BNB from user into `ZkBNB` contract
- add `Deposit` request into `priority queue`

#### depositBEP20
```
    function depositBEP20(
        IERC20 _token,
        uint104 _amount,
        address _to
    ) external;
```
Deposit BEP20 token to L2, `_to` will receive the token. This function including the following steps:
- transfer BEP20 token from user into `ZkBNB` contract
- check if the token is allowed to deposit to L2
- add `Deposit` request into `priority queue`
`
#### view functions
```
    function getNFTFactory(bytes32 _creatorAccountNameHash, uint32 _collectionId) public view returns (address);
    
    function getPendingBalance(address _address, address _assetAddr) public view returns (uint128);
```
`ZkBNB` provides some interfaces to query L1 and L2 status.
- `getNFTFactory`: get a registered NFTFactory according to the creator accountNameHash and the collectionId
- `getPendingBalance`: get pending balance that the user can withdraw


### AdditionalZkBNB

Due to a ceiling on the code size of `ZkBNB` contract, `AdditionalZkBNB` will store more logic code which could not be stored on `ZkBNB`.

### AssetGovernance
`AssetGovernance` contract is used to allow anyone to add new ERC20 tokens to ZkBNB given sufficient payment.

#### addAsset
```
    function addAsset(address _assetAddress) external;
```
This function allows anyone adds new ERC20 token to ZkBNB network.
If caller is not present in the `tokenLister` map, payment of `listingFee` in `listingFeeToken` should be made.
before calling this function make sure to approve `listingFeeToken` transfer for this contract.

### ZkBNBVerifier
`ZkBNBVerifier` contract help `ZkBNB` to verify the committed blocks and proofs.

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

## Upgradeable Design
Contracts deployed using `DeployFactory` can be upgraded to modify their code, while preserving their address, state, and balance.
This allows you to iteratively add new features to your contracts, or fix any bugs after deployed.
`DeployFactory` deploy a proxy to the implementation contract, which is the contract that you actually interact with.

Upgradeable contracts should implement `upgrade` function to be delegated by proxies. Upgradeable contracts:
- `Governance`
- `ZkBNBVerifier`
- `ZkBNB`

There are several phases to the upgrade process:

1. `startUpgrade`: start upgrade process, stored the new target implementations on `nextTargets` and noticed the community
    - `UpgradeStatus.Idle` => `UpgradeStatus.NoticePeriod`

2. `startPreparation`:  activates preparation status to be ready for upgrade
    - `UpgradeStatus.NoticePeriod` => `UpgradeStatus.Preparation`

3. `finishUpgrade`:  finishes the upgrade
    - `UpgradeStatus.Preparation` => `UpgradeStatus.Idle`

### DeployFactory
This function deploy proxies for upgradeable contracts in `ZkBNB`:
```
    function deployProxyContracts(
        DeployedContractAddress memory _contracts,
        AdditionalParams memory _additionalParams,
    ) internal;
```
The deployed implementation contract addresses should be passed in to `DeployedContractAddress` struct:
```
  struct DeployedContractAddress {
    Governance governanceTarget;
    ZkBNBVerifier verifierTarget;
    ZkBNB zkbnbTarget;
    address validator;
    address governor;
    address listingToken;
    UpgradeableMaster upgradeableMaster;
  }
```

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
This function adds a new upgradeable contract to the list of contracts managed by the `UpgradeGatekeeper`. It's called by `DeployFactory` contract on deployment.

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
```
All proxies of upgradeable contracts should implement `Upgradeable` interface for management of `UpgradeGatekeeper`.
