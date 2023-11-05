// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import {AppData, MarketRegistry} from "./MarketRegistry.sol";
import {Call} from "kernel/src/common/Structs.sol";
import {Constraints} from "../AppSample/Constraints.sol";

struct Intent {
    Call[] calls;
    uint256 appID;
    address wallet;
    bytes conditions;
    bytes orderIntent;
    uint256 closeTime;
    address creator;
    uint256 executionPeriod;
    uint256 executionDeadline;
}

struct Order {
    bytes orderIntent;
    address sender;
    uint256 score;
    uint256 submitTime;
}

contract OrderMatchEngine is Ownable {
    MarketRegistry public registry;
    uint256 intentID = 1;
    mapping(uint256=>Intent) public intentList;
    mapping(uint256=>Order) public orderInfo;

    event OrderTempWinner(uint256 intentID, uint8 scoringType, uint256 score, address sender);
    function setMarketRegistry(address registry_) public onlyOwner {
        registry = MarketRegistry(registry_);
    }

    function openIntent(uint256 appID, address wallet, Call[] memory calls, bytes memory conditions, bytes memory extraData) public {
        (uint256 closeTime) = abi.decode(extraData, (uint));
        require(closeTime > (block.timestamp + 5 minutes), "closeTime must be larger than (block.timestamp + 5 minutes)");
        Intent memory intent;
        intent.creator = msg.sender;
        intent.calls = calls;
        intent.closeTime = closeTime;
        intent.appID = appID;
        intent.wallet = wallet;
        intent.conditions = conditions;
        intentList[intentID] = intent;
        intentID++;
    }

    function submitOrder(uint256 intentID, Order memory order) public {
        Intent memory intent = intentList[intentID];
        require(intent.closeTime > block.timestamp, "Expired intent...!");
        AppData memory appdata = registry.getAppMetadata(intent.appID);
        uint8 orderFlag = Constraints(appdata.checkAddr).getOrderFlag();
        Constraints constraints = Constraints(appdata.checkAddr);

        if(orderFlag == 1){
            if(orderInfo[intentID].submitTime==0){
                orderInfo[intentID].submitTime = block.timestamp;
                orderInfo[intentID].orderIntent = order.orderIntent;
                orderInfo[intentID].sender = msg.sender;
                emit OrderTempWinner(intentID, orderFlag, type(uint256).max, msg.sender);
            }
        }
        else if(orderFlag == 2){
            uint256 orderScore = constraints.getScore(intent.conditions, orderIntent);
            if(orderInfo[intentID].score > orderInfo)
            {
                orderInfo[intentID].submitTime = block.timestamp;
                orderInfo[intentID].score = orderScore;
                orderInfo[intentID].sender = msg.sender;
                emit OrderTempWinner(intentID, orderFlag, orderScore, msg.sender);
            }
        }
        else if(orderFlag == 3){
            orderInfo[intentID].score = constraints.getScore(intent.conditions, orderIntent);
            if(orderInfo[intentID].score < orderInfo)
            {
                orderInfo[intentID].submitTime = block.timestamp;
                orderInfo[intentID].score = orderScore;
                orderInfo[intentID].sender = msg.sender;
                emit OrderTempWinner(intentID, orderFlag, orderScore, msg.sender);
            }
        }
    }

    function cancelIntent(uint256 intentId) public {
        require(msg.sender == intentList[intentId].creator);
        delete intentList[intentID];
        delete orderInfo[intentID];
    }

    function closeIntent(uint256 intentId) public {
        //require();
    }
}
