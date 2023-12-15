// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MarketRegistry.sol";
import "./Market.sol";
import "./OrderMatchEngine.sol";

import {Call} from "kernel/src/common/Structs.sol";
import {App} from "../AppSample/App.sol";
import {Constraints} from "../AppSample/Constraints.sol";

/// @title AppLauncher
/// @author windowhan (https://github.com/windowhan)
/// @notice All Intent Apps must be executed using the AppLauncher Contract.
/// @dev -
contract AppLauncher {
    MarketRegistry public marketRegistry;
    Market public market;
    OrderMatchEngine public engine;

    constructor(address _marketRegistry, address _market, address _engine) {
        marketRegistry = MarketRegistry(_marketRegistry);
        market = Market(_market);
        engine = OrderMatchEngine(_engine);
    }

    /// @notice run
    /// @dev This function checks if a user is subscribed to an Intent App based on the data uploaded to the OrderMatchEngine, and verifies whether the minimum results desired by the user have been achieved.
    /// @param intentID, This variable represents the ID of the Intent posted by the user in the Auction on the OrderMatchEngine
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
