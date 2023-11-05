// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "forge-std/console.sol";

import "../src/IntentMarket/AppLauncher.sol";
import "../src/IntentMarket/MarketRegistry.sol";
import "../src/kernel-validator/MarketValidator.sol";

import "../src/sample-intent-app/App.sol";
import "../src/sample-intent-app/Constraints.sol";

import "../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "../lib/account-abstraction/contracts/interfaces/UserOperation.sol";

import "../lib/solady/src/utils/ECDSA.sol";

import "./interfaces/IKernelFactory.sol";

contract DeployEnv is Script {
    address public admin;
    uint256 public adminPk = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    address public securityCouncil; // ex) Kalos, Trail of bits, zellic and so on...
    uint256 public securityCouncilPk = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    address public appDeveloper;
    uint256 public appDeveloperPk = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    address public walletOwner;
    uint256 public walletOwnerPk = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;

    address constant ENTRYPOINT_0_6 = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    MarketRegistry public registry;
    Market public market;

    App public app;
    Constraints public contraints;

    AppLauncher public al;
    MarketValidator public marketValidator;

    address public USDC;

    uint256 targetAppId;

    function setUp() public {
        // arbitrum fork is required
        admin = vm.addr(adminPk);
        securityCouncil = vm.addr(securityCouncilPk);
        appDeveloper = vm.addr(appDeveloperPk);
        walletOwner = vm.addr(walletOwnerPk);
        USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    }

    function run() public {
        vm.startBroadcast(walletOwnerPk);
        console.log("step1 - msg.sender : %s", vm.addr(4));
        // zerodev wallet deploy and setting.
        deployWallet();
        vm.stopBroadcast();


        vm.startBroadcast(adminPk); // admin
        adminAction();
        vm.stopBroadcast();

        vm.startBroadcast(appDeveloperPk); // App Developer
        appDevAction();
        vm.stopBroadcast();

        vm.startBroadcast(securityCouncilPk); // security council
        securityCouncilAction();
        vm.stopBroadcast();

        vm.startBroadcast(adminPk); // admin
        adminAction2();
        vm.stopBroadcast();
    }

    function deployTestWallet() public {
        address kernelFactory = 0x5de4839a76cf55d0c90e2061ef4386d962E15ae3;
        address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
        address defaultValidator = 0xd9AB5096a832b9ce79914329DAEE236f8Eea0390;
        address kernel = 0xf048AD83CB2dfd6037A43902a2A5Be04e53cd2Eb;

        UserOperation[] memory opArr = new UserOperation[](1);
        bytes memory initData = abi.encodeWithSignature("initialize(address,bytes)", defaultValidator, abi.encodePacked(walletOwner));
        address wallet = IKernelFactory(kernelFactory).getAccountAddress(initData, 0);

        opArr[0].sender = wallet;
        opArr[0].nonce = IEntryPoint(entryPoint).getNonce(wallet, 0);
        payable(wallet).call{value:1 ether}(""); // 0x8AE5602664a36449D40E79775aC66eD8D294E40f
        opArr[0].initCode = abi.encodePacked(bytes20(address(kernelFactory)), abi.encodeWithSignature("createAccount(address,bytes,uint256)", kernel, initData, 0));
        opArr[0].callData = "";
        opArr[0].callGasLimit = 20000000;
        opArr[0].verificationGasLimit = 20000000;
        opArr[0].preVerificationGas = 500000;
        opArr[0].maxFeePerGas = 500000;
        opArr[0].maxPriorityFeePerGas = 1;
        opArr[0].paymasterAndData = "";

        bytes4 mode = hex"00000000";
        //(bytes memory signature,,,) = signUserOpHash(entryPoint, 4337, opArr[0]);

        bytes32 hash = IEntryPoint(entryPoint).getUserOpHash(opArr[0]);
        console.log("userOpHash in script");
        console.logBytes32(hash);
        // walletOwner = 0x1efF47bc3a10a45D4B230B5d10E37751FE6AA718
        // hash -> 0x495de3be5832dcfacd8574be7026ed2c40bd62c91509bd34a99f7af7eaedfc52,
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(walletOwnerPk, ECDSA.toEthSignedMessageHash(hash));
        bytes memory signature = abi.encodePacked(r, s, v);
        console.log("signature in script");
        console.logBytes(signature);

        bytes memory finalSignature = abi.encodePacked(mode, signature);
        opArr[0].signature = finalSignature;
        IEntryPoint(entryPoint).handleOps(opArr, payable(walletOwner));
    }

    function adminAction() public {
        registry = new MarketRegistry();
        market = new Market(address(registry));
        console.log("MarketRegistry address : %s", address(registry));
        console.log("Market address : %s", address(market));
        registry.registerSecurityCouncil(securityCouncil);

        al = new AppLauncher(address(registry), address(market));
        console.log("AppLauncher address : %s", address(al));

        marketValidator = new MarketValidator();
        console.log("marketValidator address : %s", address(marketValidator));
    }

    function adminAction2() public {
        registry.approveFinalPass(targetAppId);
    }

    function securityCouncilAction() public {
        registry.approveSecurityCouncil(targetAppId);
    }

    function appDevAction() public {
        app = new App();
        app.setLauncher(address(al));
        contraints = new Constraints();
        //function registerAppMetadata(string calldata appName, address intentApp, address checkAddr, string memory conditionJson, address wannaSecurityCouncil, bool payFlag, address paymentCurrency, uint256 price, uint256 usePeriod) public
        string memory uijson = "{\"Inputdata\": [{\"name\": \"Input Amount\",\"uitype\": \"text\",\"datatype\": \"uint256\"},{\"name\": \"Input Asset\",\"uitype\": \"combo\",\"datatype\": \"string\", \"extraData\":[{\"text\":\"USDC\", \"value\":\"0xaf88d065e77c8cC2239327C5EDb3A432268e5831\"}, {\"text\":\"WETH\", \"value\":\"0x82aF49447D8a07e3bd95BD0d56f35241523fBab1\"}]},{\"name\": \"Output Amount\",\"uitype\": \"text\",\"datatype\": \"uint256\"},{\"name\": \"Output Asset\",\"uitype\": \"combo\",\"datatype\": \"string\", \"extraData\":[{\"text\":\"USDC\", \"value\":\"0xaf88d065e77c8cC2239327C5EDb3A432268e5831\"}, {\"text\":\"WETH\", \"value\":\"0x82aF49447D8a07e3bd95BD0d56f35241523fBab1\"}]},{\"name\":\"Market Timing\", \"uitype\":\"datetime-local\", \"datatype\":\"uint48\"}]}";
        targetAppId = registry.registerAppMetadata("testApp", address(app), address(contraints), uijson, securityCouncil, 0, address(0), 0, 0, "http://127.0.0.1:8001");
    }
}
