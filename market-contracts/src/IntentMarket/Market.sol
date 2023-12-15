// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./MarketRegistry.sol";


/// @title Market
/// @author windowhan (https://github.com/windowhan)
/// @notice When an App for executing an Intent is registered in the Market, it provides a subscription feature. Apps can be offered for free, but there is also an option to provide them for a fee.
/// @dev -
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

    /// @notice subscribe
    /// @dev The user requests a subscription to the Intent App by executing the subscribe function. If it is a paid Intent App, they must pay a specific amount in the token designated by the developer, according to the information stored in the Market Registry. This payment allows for a subscription for a certain period.
    /// @param appId Intent App ID
    /// @return The user requests a subscription to an Intent App. If it is a paid Intent App, a specific amount must be paid in the token designated by the developer, according to the information stored in the MarketRegistry. This payment allows for a subscription for a certain period. The result indicates whether this series of processes has been executed successfully.
    function subscribe(uint256 appId) public returns (bool){
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

    /// @notice checkExpireSubscription
    /// @dev It is a function that checks whether the user's subscription period has expired.
    /// @param appId Intent App ID
    /// @param wallet The address of the wallet that executes intent
    function checkExpireSubscription(uint256 appId, address wallet) public view {
        Subscription memory data = subscriptionData[appId][wallet];
        if(data.startTime == 0) {
            revert("Please purchase intent application");
        }

        if(data.endTime < block.timestamp) {
            revert("Expired Period");
        }
    }
}