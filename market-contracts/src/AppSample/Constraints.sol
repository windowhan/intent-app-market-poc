// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "../IntentMarket/OrderBook.sol";


contract Constraints is Ownable {
    OrderBook public orderBook;
    uint8 scoringType=1;

    function setScoringType(uint8 variable) public onlyOwner {
        scoringType = variable;
    }

    function setOrderBook(address orderBook_) public onlyOwner{
        orderBook = OrderBook(orderBook_);
    }

    function getScoringType() external view returns (uint8) {
        // 0 - 빨리 Order 제출한 사람이 Winner
        // 1 - Score 오름차순으로 Winner 산출
        // 2 - Score 내림차순으로 Winner 산출
        return scoringType;
    }

    function getScore(bytes calldata conditions, bytes calldata orderIntent) external view returns (uint256 score) {
        uint256 outputAmount = uint256(bytes32(conditions[52:84]));
        uint256 submitOutputAmount = uint256(bytes32(orderIntent[0:32]));
        return (submitOutputAmount-outputAmount);
    }

    function getPrevState(address wallet, bytes calldata config) external view returns (bytes memory) {
        address swapInputAsset = address(uint160(bytes20(config[0:20])));
        address swapOutputAsset = address(uint160(bytes20(config[20:40])));

        uint256 prevInputAssetBalance = IERC20(swapInputAsset).balanceOf(wallet);
        uint256 prevOutputAssetBalance = IERC20(swapOutputAsset).balanceOf(wallet);

        return abi.encode(prevInputAssetBalance, prevOutputAssetBalance);
    }

    function check(address wallet, bytes calldata prevState, bytes calldata conditions, bytes calldata orderIntent) external view returns (bool) {
        // swap input, swap output, time condition
        // In this POC, we will not implement the Stop loss or Take Profit Order.
        // For Stop loss or Take Profit Order, you can utilize the Custom Oracle within the Constraints contract.
        // We'll consider implementing it later on.
        uint256 swapInput = uint256(bytes32(conditions[0:32]));
        address swapInputAsset = address(uint160(bytes20(conditions[32:52])));
        uint256 swapOutput = uint256(bytes32(conditions[52:84]));
        address swapOutputAsset = address(uint160(bytes20(conditions[84:104])));
        uint256 marketTiming = uint256(bytes32(conditions[104:136]));

        uint256 prevInputAssetBalance = uint256(bytes32(prevState[0:32]));
        uint256 prevOutputAssetBalance = uint256(bytes32(prevState[32:64]));

        address _wallet = wallet;
        uint256 afterInputAssetBalance = IERC20(swapInputAsset).balanceOf(_wallet);
        uint256 afterOutputAssetBalance = IERC20(swapOutputAsset).balanceOf(_wallet);

        uint256 inputAmount = prevInputAssetBalance - afterInputAssetBalance;
        uint256 outputAmount = afterOutputAssetBalance - prevOutputAssetBalance;
        uint256 submitOutputAmount = uint256(bytes32(orderIntent[0:32]));

        if(swapInput < inputAmount) {
            revert("too much input amount!!!");
        }

        if(swapOutput > submitOutputAmount) {
            revert("too little output amount!!!");
        }

        if(marketTiming < block.timestamp) {
            revert("not ready..");
        }
        return true;
    }
}