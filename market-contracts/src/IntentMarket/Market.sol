// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./MarketRegistry.sol";


contract Market {
    MarketRegistry public registry;

    struct Subscription {
        bool payFlag;
        address paymentCurrency;
        uint256 price;
        uint256 startTime;
        uint256 endTime;
        address user;
    }

    mapping(uint256 => mapping(address=>Subscription)) subscriptionData;

    constructor(address _registry) {
        registry = MarketRegistry(_registry);
    }

    function purchase(uint256 appId) public returns (bool){
        (uint8 payFlag, address paymentCurrency, uint128 price, uint48 usePeriod, address creator) = registry.getAppPaymentInfo(appId);
        Subscription memory ss;
        if(payFlag == 0){
            ss.payFlag = false;
            ss.paymentCurrency = address(0);
            ss.price = 0;
            ss.startTime = block.timestamp;
            ss.endTime = type(uint256).max;
            subscriptionData[appId][msg.sender] = ss;
            return true;
        }

        IERC20(paymentCurrency).transferFrom(msg.sender, creator, price);
        ss.payFlag = true;
        ss.paymentCurrency = address(paymentCurrency);
        ss.price = price;
        ss.startTime = block.timestamp;
        ss.endTime = block.timestamp + usePeriod;
        subscriptionData[appId][msg.sender] = ss;
        return true;
    }

    function checkExpireSubscription(uint256 appId, address user) public view {
        Subscription memory data = subscriptionData[appId][user];
        if(data.startTime == 0) {
            revert("Please purchase intent application");
        }

        if(data.endTime < block.timestamp) {
            revert("Expired Period");
        }
    }
}