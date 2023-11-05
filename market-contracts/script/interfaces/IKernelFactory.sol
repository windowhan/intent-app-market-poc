// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IKernelFactory {
    function getAccountAddress(bytes calldata _data, uint256 _index) external view returns (address);
}