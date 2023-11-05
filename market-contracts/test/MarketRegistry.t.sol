// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {MarketRegistry} from "../src/IntentMarket/MarketRegistry.sol";
import {Util} from "./util/util.sol";


contract MarketRegistryTest is Test, Util {
    address public admin;
    address public securityCouncil;
    address public appDevelper;
    address public wallet;
    address public walletOwner;

    function setUp() public {
        admin = vm.addr(1);
        securityCouncil = vm.addr(2);
        appDevelper = vm.addr(3);
        walletOwner = vm.addr(4);
    }

    function testRegistry() public {
    }
}
