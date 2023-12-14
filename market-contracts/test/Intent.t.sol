// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Util} from "./util/util.sol";

import {MarketRegistry, AppData} from "../src/IntentMarket/MarketRegistry.sol";
import {Market} from "../src/IntentMarket/Market.sol";
import {AppLauncher} from "../src/IntentMarket/AppLauncher.sol";
import {OrderMatchEngine, Order} from "../src/IntentMarket/OrderMatchEngine.sol";

import {App} from "../src/AppSample/App.sol";
import {Constraints} from "../src/AppSample/Constraints.sol";
import {SolverHelper} from "../src/SolverSample/SolverHelper.sol";

import {Call} from "kernel/src/common/Structs.sol";
import {Operation} from "kernel/src/common/Enums.sol";
import {Kernel} from "kernel/src/Kernel.sol";
import {KernelFactory} from "kernel/src/factory/KernelFactory.sol";
import {KernelStorage} from "kernel/src/abstract/KernelStorage.sol";
import {ECDSAValidator} from "kernel/src/validator/ECDSAValidator.sol";
import {ERC4337Utils} from "kernel/test/foundry/utils/ERC4337Utils.sol";

import {IEntryPoint, UserOperation} from "I4337/interfaces/IEntryPoint.sol";

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
    using ERC4337Utils for IEntryPoint;

contract IntentTest is Test, Util {
    address public admin;
    address public securityCouncil;
    address public appDeveloper;
    Kernel public wallet;
    address public walletOwner;
    address public factoryOwner;
    address public solver;

    address public entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    MarketRegistry public marketRegistry;
    Market public market;
    AppLauncher public launcher;
    OrderMatchEngine public engine;

    App public sampleApp;
    Constraints public sampleConstraints;

    function setUp() public {
        readyRole();
        vm.startPrank(factoryOwner);
        wallet = deploy4337Wallet(IEntryPoint(entryPoint), factoryOwner, walletOwner);
        vm.stopPrank();
        console.log("4337 wallet(ZeroDev) address : %s", address(wallet));

        deployInfra();
    }

    function readyRole() public {
        admin = vm.addr(1);
        securityCouncil = vm.addr(2);
        appDeveloper = vm.addr(3);
        walletOwner = vm.addr(4);
        factoryOwner = vm.addr(5);
        solver = vm.addr(6);
    }

    function deploy4337Wallet(IEntryPoint ep, address factoryOwner_, address walletOwner_) public returns (Kernel kernel){
        KernelFactory factory = new KernelFactory(factoryOwner_, ep);
        Kernel kernelImpl = new Kernel(ep);
        factory.setImplementation(address(kernelImpl), true);

        ECDSAValidator defaultValidator = new ECDSAValidator();

        bytes memory initialData = abi.encodeWithSelector(KernelStorage.initialize.selector, defaultValidator, abi.encodePacked(walletOwner_));
        Kernel w = Kernel(payable(address(factory.createAccount(address(kernelImpl), initialData, 0))));
        deal(address(w), 1 ether);
        return w;
    }

    function deployInfra() public {
        vm.startPrank(admin);
        marketRegistry = new MarketRegistry();
        marketRegistry.registerSecurityCouncil(securityCouncil);
        market = new Market(address(marketRegistry));
        engine = new OrderMatchEngine();
        launcher = new AppLauncher(address(marketRegistry), address(market), address(engine));
        engine.setMarketRegistry(address(marketRegistry));
        vm.stopPrank();
    }

    function deployTestApp() public returns (uint256){
        vm.startPrank(appDeveloper);
        sampleApp = new App();
        sampleApp.setLauncher(address(launcher));
        sampleConstraints = new Constraints();
        AppData memory appData;
        appData.appName = "Test Swap Intent App";
        appData.appAddr = address(sampleApp);
        appData.checkAddr = address(sampleConstraints);
        appData.uiMetaJson = "Test UI MetaData";
        appData.creator = appDeveloper;
        appData.approveSecurityCouncil = securityCouncil;
        appData.payFlag = 0;
        appData.paymentCurrency = address(0);
        appData.price = 0;
        appData.usePeriod = type(uint48).max;
        appData.description = "This is Test App!!!";

        uint256 appId = marketRegistry.registerAppMetadata(appData);
        console.log("registerAppMetadata in marketRegistry | appId : %d", appId);
        vm.stopPrank();

        vm.warp(block.timestamp+3601);
        vm.startPrank(securityCouncil);
        marketRegistry.approveSecurityCouncil(appId);
        console.log("approveSecurityCouncil completed..");
        vm.stopPrank();

        vm.warp(block.timestamp+3601);
        vm.startPrank(admin);
        marketRegistry.approveFinalPass(appId);
        console.log("approveFinalPass completed...");
        vm.stopPrank();
    }

    function signUserOp(UserOperation memory op, uint256 ownerKey) internal view returns (bytes memory) {
        return abi.encodePacked(bytes4(0x00000000), IEntryPoint(entryPoint).signUserOpHash(vm, ownerKey, op));
    }


    function testFullScenario() public {
        uint256 appId = deployTestApp();
        // 구독
        UserOperation memory subop = IEntryPoint(entryPoint).fillUserOp(
            address(wallet),
            abi.encodeWithSelector(
                Kernel.execute.selector,
                address(market),
                0,
                abi.encodeWithSelector(Market.subscribe.selector, 0),
                Operation.Call
            )
        );
        subop.signature = signUserOp(subop, 4);
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = subop;
        IEntryPoint(entryPoint).handleOps(ops, payable(address(0xdeaddead)));


        address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

        deal(USDC, address(wallet), 1000*(10**6)); // 1000 USDC
        vm.startPrank(walletOwner, walletOwner);

        uint256 swapInput = 1000*(10**6);
        address swapInputAsset = USDC;
        uint256 swapOutput = 0.001 ether;
        address swapOutputAsset = WETH;
        uint256 marketTiming = 0;
        bytes memory condition = abi.encodePacked(swapInput, swapInputAsset, swapOutput, swapOutputAsset, marketTiming);
        Call[] memory calls = sampleApp.getUserCallData(address(wallet), condition, 0);

        UserOperation memory intentOp = IEntryPoint(entryPoint).fillUserOp(address(wallet),
            abi.encodeWithSelector(
                Kernel.executeBatch.selector,
                calls
            )
        );

        intentOp.nonce += 1;
        intentOp.signature = signUserOp(intentOp, 4);
        bytes memory extraData = abi.encode(uint256(600), intentOp);
        UserOperation memory op = IEntryPoint(entryPoint).fillUserOp(
            address(wallet),
            abi.encodeWithSelector(
                Kernel.execute.selector,
                address(engine),
                0,
                abi.encodeWithSelector(OrderMatchEngine.openIntent.selector, appId, address(wallet), condition, extraData),
                Operation.Call
            )
        );
        op.signature = signUserOp(op, 4);

        ops[0] = op;
        IEntryPoint(entryPoint).handleOps(ops, payable(address(0xdead)));
        vm.stopPrank();

        vm.startPrank(solver, solver);
        engine.submitOrder(0, abi.encodePacked(uint256(0.1 ether)));
        vm.warp(block.timestamp+800);

        address matchWinner = engine.getWinner(0);
        console.log("matchWinner : %s, solver : %s", matchWinner, solver);
        SolverHelper helper = new SolverHelper();
        helper.setInfra(address(entryPoint), address(sampleApp), address(engine), address(launcher), address(market), address(marketRegistry));
        address uniswapRouter = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        address[] memory paths = new address[](3);
        paths[0] = USDC;
        paths[1] = DAI;
        paths[2] = WETH;
        helper.run(0, uniswapRouter, paths);
        vm.stopPrank();
    }
}
