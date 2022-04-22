// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

//import "https://github.com/Openzeppelin/openzeppelin-contracts/blob/release-v3.4/contracts/token/ERC20/ERC20.sol";
//import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ERC20.sol";

contract ZecreyRelatedERC20 is ERC20 {
    constructor(uint256 _initialSupply, string memory _name, string memory _symbol) ERC20(_name, _symbol){
        _mint(msg.sender, _initialSupply);
    }
}