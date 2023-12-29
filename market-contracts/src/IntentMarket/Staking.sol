// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

abstract contract Staking is Ownable {
    mapping(address=>uint256) public deposits;

    function deposit() external payable {
        deposits[tx.origin] = msg.value;
    }

    function slashBasicOrder() external {

    }

    receive() external payable {}
}
