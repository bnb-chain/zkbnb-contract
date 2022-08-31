# zkbas-contract

Contracts for zkbas.

## Zkbas
Zkbas contract is the core entry of the whole system.

```
    function commitBlocks(
        StoredBlockInfo memory _lastCommittedBlockData,
        CommitBlockInfo[] memory _newBlocksData
    )
    external
```
Validators commit blocks from L2 to L1 and the blocks will be stored on L1 for later validation.
Commit one block includes the following steps:
- check blockNumber, timestamp
- check if onchain operations from the committed block are same as the transactions in priority queue. 
All onchain operations below:  
    - `RegisterZNS`: register ZNS name 
    - `CreatePair`: create token pair for token swap on L2
    - `UpdatePairRate`: update fee rate of the token pair 
    - `Deposit`: deposit token from L1 to L2
    - `Withdraw`: withdraw token from L2 to L1
    - `WithdrawNft`: withdraw NFT from L2 to L1
    - `FullExit`: request exit BNB from L2 to L1
    - `FullExitNft`: request exit BNB from L2 to L1
- create block commitment for verification proof
- store block data

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
A `CommitBlock` contains block information, transaction data and the state root after the transaction data has been executed.
Block information contains `timestamp`, `blockNumber` and `blockSize`. 
L2 transaction data is packed in `CommitBlockInfo.publicData`

```
    function verifyAndExecuteBlocks(VerifyAndExecuteBlockInfo[] memory _blocks, uint256[] memory _proofs) external;
    
    function verifyAndExecuteOneBlock(VerifyAndExecuteBlockInfo memory _block, uint32 _verifiedBlockIdx) internal;
```

Verify and execute stored blocks from `commitBlocks`.
`verifyAndExecuteOneBlock` includes the following steps:
- check if the input block was committed from `commitBlocks` and the input blocks are in correct order
- check if the pending onchain operations are correct

```
    function registerZNS(string calldata _name, address _owner, bytes32 _zkbasPubKeyX, bytes32 _zkbasPubKeyY) external payable;
```
Add request that registering a ZNS name into priority queue.


```
    function depositBNB(string calldata _accountName) external payable;
```
Deposit native asset to L2, `_accountName` will receive the BNB. This function including the following steps:
- transfer BNB from user into `Zkbas` contract
- add `Deposit` request into priority queue


```
    function depositBEP20(
        IERC20 _token,
        uint104 _amount,
        string calldata _accountName
    ) external;
```
Deposit BEP20 token to L2, `_accountName` will receive the token. This function including the following steps:
- transfer BEP20 token from user into `Zkbas` contract
- check if the token is allowed to deposit to L2
- add `Deposit` request into priority queue


```
    function getAddressByAccountNameHash(bytes32 accountNameHash) public view returns (address);

    function isRegisteredZNSName(string memory name) external view returns (bool);

    function getZNSNamePrice(string calldata name) external view returns (uint256);
    
    function getNFTFactory(bytes32 _creatorAccountNameHash, uint32 _collectionId) public view returns (address);
    
    function getPendingBalance(address _address, address _assetAddr) public view returns (uint128);
```
`Zkbas` provides some interfaces to query L1 and L2 status.
- `getAddressByAccountNameHash`: 
- `isRegisteredZNSName`: check if the provided ZNS name is registered
- `getZNSNamePrice`: get the price of the provided ZNS name
- `getNFTFactory`: get a registered NFTFactory according to the creator accountNameHash and the collectionId
- `getPendingBalance`: get pending balance that the user can withdraw


## AdditionalZkbas

Due to a ceiling on the size of `Zkbas` contract, `AdditionalZkbas` will store more logic which could not be stored on `Zkbas`.


```
    function createPair(address _tokenA, address _tokenB) external;
```

Create token pair for token swap on L2. This function including the following steps:
- check if the pair of provided tokens already exists and the provided tokens are allowed to create pair on L2
- If caller is not present in the `tokenLister` map, payment of `listingFee` in `listingFeeToken` should be made
- record new token pair on L1
- add `CreatePair` request into priority queue


```
    function updatePairRate(PairInfo memory _pairInfo) external;
```

Update the fee rate of provided pair on L2. This function including the following steps:
- check if the pair exists and tokens are allowed to update fee rate
- update token pair fee rate on L1
- add `UpdatePairRate` request into priority queue


## Zkbas Name Service

Zkbas Name Service(ZNS) is a name service between L1 and L2. Users should register name in L1 
and set his L2 account address(Bytes32 public key) with this name. So that this user can use this name
both in L1 and L2.

Names are stored as node in contracts. Each node is mapped by a byte32 name hash. 
The name hash can be calculated as below(a Javascript implementation is in ./test/zns-registry.js):

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

All ZNS lookups start by querying the registry. The registry contains records of Zkbas short name, recording the
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

It provides external functions for users to register (and transfer) Zkbas names.

It also maintains a mapper from L2Account to node's name hash, which can be used to assure
each L2 account can only own one name.

It defines external methods:
1. register: register a not existed name for a specified address, which actually invokes safeMint to mint a name node nft.

### ZNSResolver

A resolver is used to resolve detailed information of a name in L1, like a text, public key 
connected with this node.

A external contract should implement the Resolver.sol and the owner of nodes can set this contract 
as the resolver for his nodes. Then others can resolve this name for detailed information by calling this external contract.

## AssetGovernance
`AssetGovernance` contract is used to allow anyone to add new ERC20 tokens to Zkbas given sufficient payment.

```
    function addAsset(address _assetAddress) external;
```
This function allows anyone adds new ERC20 token to Zkbas network.
If caller is not present in the `tokenLister` map, payment of `listingFee` in `listingFeeToken` should be made.
before calling this function make sure to approve `listingFeeToken` transfer for this contract.

## ZkbasVerifier
`ZkbasVerifier` contract help `Zkbas` to verify the committed blocks and proofs.

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


