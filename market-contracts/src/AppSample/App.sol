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

/// @title App
/// @author windowhan (https://github.com/windowhan)
/// @notice It is a contract that includes on-chain logic for executing intent.
/// @dev It is a contract that includes on-chain logic for executing intent.
contract App is Ownable{
    struct PathList {
        address[] path;
    }

    mapping(address=>mapping(address=>PathList)) pathOptimization;
    address public router;
    address public appLauncher;

    /*
        The setLauncher, setRouter, and setPath functions are for the Sample. They are not always required to be defined.
    */
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

    /// @notice getUserCallData
    /// @dev It is a function that defines the actions that need to be processed as per the user's desire within the intent.
    /// @param owner, The address of the wallet owner
    /// @param args, It is the data required to define the intent.
    /// @param intentID, It is the ID of the intent that needs to be assigned in the OrderMatchEngine Contract.
    /// @return calls, It is the value that defines what action the intent will take.
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

    /// @notice App's main function
    /// @dev It is a formalized function that encapsulates the logic where the intent is actually executed.
    /// @param wallet, The address of the wallet that executes intent
    /// @param args, It is the data required to define the intent.
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