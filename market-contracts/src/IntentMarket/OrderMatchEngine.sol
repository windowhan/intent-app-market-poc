// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {AppData, MarketRegistry} from "./MarketRegistry.sol";
import {Call} from "kernel/src/common/Structs.sol";
import {Constraints} from "../AppSample/Constraints.sol";
import {IEntryPoint, UserOperation} from "I4337/interfaces/IEntryPoint.sol";
import {Staking} from "./Staking.sol";


import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "forge-std/console.sol";

    struct Intent {
    uint256 appID;
    address wallet;
    bytes conditions;
    uint256 closeTime;
    address creator;
    uint256 executionPeriod;
    uint256 executionDeadline;
        bool executed;
    UserOperation op;
}

struct Order {
    bytes orderIntent;
    address sender;
    uint256 score;
    uint256 submitTime;
}

contract OrderMatchEngine is Ownable, Staking {
    MarketRegistry public registry;
    address public launcher;
    uint256 intentCount = 0;
    mapping(uint256=>Intent) public intentList;
    mapping(uint256=>Order) public orderInfo;

    event OrderTempWinner(uint256 intentID, uint8 scoringType, uint256 score, address sender);
    event OpenIntent(uint256 intentID, address creator, uint256 closeTime, uint256 appID, address wallet);

    function setMarketRegistry(address registry_) public onlyOwner {
        registry = MarketRegistry(registry_);
    }

    function setLauncher(address launcher_) public onlyOwner {
        launcher = launcher_;
    }

    function openIntent(uint256 appID, address wallet, bytes memory conditions, bytes memory extraData) public returns (uint256 intentId){
        (uint256 closeTime, UserOperation memory userOp) = abi.decode(extraData, (uint, UserOperation));
        require((block.timestamp + closeTime) >= (block.timestamp + 5 minutes), "closeTime must be larger than (block.timestamp + 5 minutes)");
        require(msg.sender == wallet, "invalid msg.sender");
        Intent memory intent;
        intent.creator = msg.sender;
        intent.closeTime = block.timestamp + closeTime;
        intent.appID = appID;
        intent.wallet = wallet;
        intent.conditions = conditions;
        intent.op = userOp;
        intentList[intentCount] = intent;
        emit OpenIntent(intentCount, intent.creator, intent.closeTime, appID, intent.wallet);
        intentCount++;
        return intentCount-1;
    }

    function getWinner(uint256 intentID) public view returns (address) {
        Intent memory intent = intentList[intentID];
        require(intent.closeTime < block.timestamp, "too fast");

        return orderInfo[intentID].sender;
    }

    function getOp(uint256 intentID) public view returns (UserOperation memory) {
        return intentList[intentID].op;
    }

    function submitOrder(uint256 intentID, bytes memory orderIntent) public {
        Intent memory intent = intentList[intentID];
        console.log("current block.timestamp : %d", block.timestamp);
        require(intent.closeTime > block.timestamp, "The submission time for the order has already passed.");
        AppData memory appdata = registry.getAppMetadata(intent.appID);
        uint8 orderTypeFlag = Constraints(appdata.checkAddr).getScoringType();
        Constraints constraints = Constraints(appdata.checkAddr);


        address[] memory whitelistExecutor = appdata.whitelistExecutor;
        bool executeFlag = false;

        if(whitelistExecutor.length==0)
            executeFlag = true;
        else {
            for(uint i=0;i<whitelistExecutor.length;i++){
                if(tx.origin==whitelistExecutor[i])
                    executeFlag = true;
            }
        }

        require(executeFlag == true, "No permission submitOrder");

        if(orderTypeFlag == 0){
            if(orderInfo[intentID].submitTime==0){
                orderInfo[intentID].submitTime = block.timestamp;
                orderInfo[intentID].orderIntent = orderIntent;
                orderInfo[intentID].sender = tx.origin;
                emit OrderTempWinner(intentID, orderTypeFlag, type(uint256).max, tx.origin);
            }
        }
        else if(orderTypeFlag == 1){
            uint256 orderScore = constraints.getScore(intent.conditions, orderIntent);
            if(orderInfo[intentID].score < orderScore)
            {
                orderInfo[intentID].submitTime = block.timestamp;
                orderInfo[intentID].orderIntent = orderIntent;
                orderInfo[intentID].score = orderScore;
                orderInfo[intentID].sender = tx.origin;
                emit OrderTempWinner(intentID, orderTypeFlag, orderScore, tx.origin);
            }
        }
        else if(orderTypeFlag == 2){
            uint256 orderScore = constraints.getScore(intent.conditions, orderIntent);
            if(orderInfo[intentID].score > orderScore)
            {
                orderInfo[intentID].submitTime = block.timestamp;
                orderInfo[intentID].orderIntent = orderIntent;
                orderInfo[intentID].score = orderScore;
                orderInfo[intentID].sender = tx.origin;
                emit OrderTempWinner(intentID, orderTypeFlag, orderScore, tx.origin);
            }
        }
    }

    function cancelIntent(uint256 intentId) public {
        require(msg.sender == intentList[intentId].creator && intentList[intentId].closeTime < block.timestamp);
        delete intentList[intentId];
        delete orderInfo[intentId];
    }

    function setExecuted(uint256 intentId) public {
        require(msg.sender == launcher && intentList[intentId].executed==false);
        require(intentList[intentId].closeTime > block.timestamp);
        intentList[intentId].executed = true;
    }

    function forceCloseIntent(uint256 intentId) public {
        require(intentList[intentId].closeTime < block.timestamp);
        require(intentList[intentId].creator==msg.sender);
        intentList[intentId].closeTime = block.timestamp;
    }
}
