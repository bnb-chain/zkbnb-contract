// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

interface IMulticallable {
    function multicall(bytes[] calldata data) external returns(bytes[] memory results);
}
