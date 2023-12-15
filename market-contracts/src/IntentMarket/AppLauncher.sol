// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MarketRegistry.sol";
import "./Market.sol";
import "./OrderMatchEngine.sol";

import {Call} from "kernel/src/common/Structs.sol";
import {App} from "../AppSample/App.sol";
import {Constraints} from "../AppSample/Constraints.sol";

/// @notice AppLauncher
/// @author windowhan (https://github.com/windowhan)
contract AppLauncher {
    MarketRegistry public marketRegistry;
    Market public market;
    OrderMatchEngine public engine;

    constructor(address _marketRegistry, address _market, address _engine) {
        marketRegistry = MarketRegistry(_marketRegistry);
        market = Market(_market);
        engine = OrderMatchEngine(_engine);
    }

    // 파라미터에서 contraints랑 prevStateParseConfig 제거
    function run(uint256 intentID) public {
        require(engine.getWinner(intentID) == tx.origin, "not winner!");

        (uint256 appId, address wallet, bytes memory constraints,,,,uint256 executionDeadline, bool executed,UserOperation memory op) = engine.intentList(intentID);
        require(executed==false, "already executed!");
        (bytes memory orderIntent,,,) = engine.orderInfo(intentID);
        (address appAddr, address checkAddr) = marketRegistry.getAppExecutionInfo(appId);
        market.checkExpireSubscription(appId, msg.sender);

        bytes memory prevState = Constraints(checkAddr).getPrevState(msg.sender, constraints);
        App(appAddr).main(msg.sender, constraints);
        if(Constraints(checkAddr).check(msg.sender, prevState, constraints, orderIntent)==false)
            revert("constraints violation!");
        engine.setExecuted(intentID);
    }
}

/*
일어나면 해야할거

** 어떻게 AppLauncher의 run함수를 실행하는 payload를 generate하지?
-> UserOperation을 generate해서 아예 올려버리기. (nonce replace attack(?)이 가능할 수 있지만 일단 올려보자)
-> 나중에는 별도의 Validator를 만들어서 플레이해볼 수 있을 것

1. AppLauncher에서 constraints랑 prevStateParseConfig 제거하기.
2. AppLauncher에서 OrderMatch Winner만 접근 가능하게 만들기.
3. 실행까지 완벽하게 하게 만들기
*/