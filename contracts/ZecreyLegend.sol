// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.7.6;

import "./Storage.sol";
import "./ZNSFIFSRegistrar.sol";

contract ZecreyLegend is ZNSFIFSRegistrar, Storage {

    bytes32 LEGEND_NODE = 0xae8f26d798b83a4b456e65b30ab9344705ca7577ffb1814c91f94da90da82de5;

    constructor(ZNS zns) ZNSFIFSRegistrar(zns, LEGEND_NODE) {

    }

}
