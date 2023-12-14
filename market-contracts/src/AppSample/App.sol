// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {AppLauncher} from "../IntentMarket/AppLauncher.sol";
import {Call} from "kernel/src/common/Structs.sol";

interface IRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}


contract App is Ownable{
    struct PathList {
        address[] path;
    }

    mapping(address=>mapping(address=>PathList)) pathOptimization;
    address public router;
    address public appLauncher;

    function setLauncher(address _appLauncher) public {
        appLauncher = _appLauncher;
    }

    function setRouter(address _router) public {
        router = _router;
    }
    function setPath(address from, address to, address[] calldata pathList) public {
        PathList memory list;
        list.path = pathList;
        pathOptimization[from][to] = list;
    }

    // getUserCallData와 main은 꼭 짜여져야함.
    function getUserCallData(address owner, bytes calldata args, uint256 intentID) public view returns (Call[] memory) {
        uint256 swapInput = uint256(bytes32(args[0:32]));
        address swapInputAsset = address(uint160(bytes20(args[32:52])));

        Call[] memory processedArgs = new Call[](2);
        processedArgs[0].to = swapInputAsset;
        processedArgs[0].data = abi.encodeWithSelector(IERC20.approve.selector, address(this), swapInput);

        processedArgs[1].to = appLauncher;
        processedArgs[1].data = abi.encodeWithSelector(AppLauncher.run.selector, intentID);

        return processedArgs;
    }

    function main(address wallet, bytes calldata args) public {
        if(msg.sender!=appLauncher){
            revert("appLauncher only!");
        }

        uint256 swapInput = uint256(bytes32(args[0:32]));
        address swapInputAsset = address(uint160(bytes20(args[32:52])));
        address swapOutputAsset = address(uint160(bytes20(args[84:104])));

        IERC20(swapInputAsset).transferFrom(wallet, address(this), swapInput);
        IERC20(swapInputAsset).approve(router, type(uint256).max);
        PathList memory optPath = pathOptimization[swapInputAsset][swapOutputAsset];
        if(optPath.path.length == 0) {
            revert("not set path");
        }

        IRouter(router).swapExactTokensForTokens(swapInput, 0, optPath.path, wallet, block.timestamp*2);
        IERC20(swapInputAsset).approve(router, 0);
    }
}