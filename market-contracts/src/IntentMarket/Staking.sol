// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

abstract contract Staking {
    mapping(address=>uint256) public deposits;

    function deposit() external payable {
        deposits[tx.origin] = msg.value;
    }
    receive() external payable {}
}
