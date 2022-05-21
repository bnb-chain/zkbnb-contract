// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;
pragma abicoder v2;

import "./Multicallable.sol";
import "./profile/ABIResolver.sol";
import "./profile/AddrResolver.sol";
import "./profile/PubKeyResolver.sol";
import "./profile/NameResolver.sol";
import "../ZNS.sol";
import "./profile/ZecreyPubKeyResolver.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * A simple resolver anyone can use; only allows the owner of a node to set its address.
 */
contract PublicResolver is
Multicallable,
ABIResolver,
AddrResolver,
NameResolver,
PubKeyResolver,
ZecreyPubKeyResolver,
ReentrancyGuardUpgradeable
{
    ZNS zns;

    /**
     * @dev A mapping of operators. An address that is authorised for an address
     * may make any changes to the name that the owner could, but may not update
     * the set of authorisations.
     * (owner, operator) => approved
     */
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Logged when an operator is added or removed.
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    function initialize(bytes calldata initializationParameters) external initializer {
        __ReentrancyGuard_init();

        (
        address _zns
        ) = abi.decode(initializationParameters, (address));
        zns = ZNS(_zns);
    }

    function zecreyPubKey(bytes32 node) override external view returns (bytes32 pubKey) {
        return zns.pubKey(node);
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) external {
        require(
            msg.sender != operator,
            "ERC1155: setting approval status for self"
        );

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator)
    public
    view
    returns (bool)
    {
        return _operatorApprovals[account][operator];
    }

    function isAuthorised(bytes32 node) internal view override returns (bool) {
        address owner = zns.owner(node);
        return owner == msg.sender || isApprovedForAll(owner, msg.sender);
    }

    function supportsInterface(bytes4 interfaceID)
    public
    pure
    override(
    Multicallable,
    ABIResolver,
    AddrResolver,
    NameResolver,
    PubKeyResolver,
    ZecreyPubKeyResolver
    )
    returns (bool)
    {
        return super.supportsInterface(interfaceID);
    }
}
