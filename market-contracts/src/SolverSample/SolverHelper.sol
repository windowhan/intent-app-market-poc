// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../IntentMarket/Market.sol";
import "../IntentMarket/MarketRegistry.sol";
import "../IntentMarket/AppLauncher.sol";
import "../IntentMarket/OrderMatchEngine.sol";
import "../AppSample/App.sol";

import {IEntryPoint, UserOperation} from "I4337/interfaces/IEntryPoint.sol";


contract SolverHelper {
    AppLauncher public launcher;
    Market public market;
    MarketRegistry public registry;
    App public app;
    OrderMatchEngine public engine;
    IEntryPoint public ep;

    function setInfra(address ep_, address app_, address engine_, address launcher_, address market_, address registry_) public {
        launcher = AppLauncher(launcher_);
        market = Market(market_);
        app = App(app_);
        registry = MarketRegistry(registry_);
        engine = OrderMatchEngine(engine_);
        ep = IEntryPoint(payable(ep_));
    }

    function run(uint256 intentID, address router, address[] memory paths) public {
        app.setPath(paths[0], paths[paths.length-1], paths);
        app.setRouter(router);

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = engine.getOp(intentID);
        ep.handleOps(ops, payable(address(this)));
    }

    receive() external payable {}
}
