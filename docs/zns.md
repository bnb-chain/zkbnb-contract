## ZkBNB Name Service

ZkBNB Name Service(ZNS) is a name service between L1 and L2. Users should register name in L1
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

All ZNS lookups start by querying the registry. The registry contains records of ZkBNB short name, recording the
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

It provides external functions for users to register (and transfer) ZkBNB names.

It also maintains a mapper from L2Account to node's name hash, which can be used to assure
each L2 account can only own one name.

It defines external methods:
1. register: register a not existed name for a specified address, which actually invokes safeMint to mint a name node nft.

### ZNSResolver

A resolver is used to resolve detailed information of a name in L1, like a text, public key
connected with this node.

An external contract should implement the `Resolver.sol` and the owner of nodes can set this contract
as the resolver for his nodes. Then others can resolve this name for detailed information by calling this external contract.
