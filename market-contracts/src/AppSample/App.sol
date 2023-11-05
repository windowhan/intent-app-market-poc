// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

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

    function setLauncher(address _appLauncher) public onlyOwner {
        appLauncher = _appLauncher;
    }

    function setConfig(address _router) public onlyOwner {
        router = _router;
    }
    function setPath(address from, address to, address[] calldata pathList) public onlyOwner {
        PathList memory list;
        list.path = pathList;
        pathOptimization[from][to] = list;
    }

    // getUserCallData와 main은 꼭 짜여져야함.
    function getUserCallData(address owner, bytes memory args) public view returns (Call[] memory) {
        // getUserCallData 인자로 들어가는 data와 main에 들어가는 args는 똑같아야함.
        address fromAsset = address(uint160(bytes20(args[0:20])));
        address toAsset = address(uint160(bytes20(args[20:40])));
        uint256 amount = uint256(bytes32(args[40:72]));

        Call[] memory processedArgs = new Call[](2);
        processedArgs[0].to = fromAsset;
        processedArgs[0].data = abi.encodeWithSelector(IERC20.approve.selector, address(this), amount);

        processedArgs[1].to = address(this);
        processedArgs[1].data = abi.encodeWithSelector(this.main.selector, owner, args);

        return processedArgs;
    }

    function main(address owner, bytes calldata args) public {
        if(msg.sender!=appLauncher){
            revert("appLauncher only!");
        }
        address fromAsset = address(uint160(bytes20(args[0:20])));
        address toAsset = address(uint160(bytes20(args[20:40])));
        uint256 amount = uint256(bytes32(args[40:72]));

        IERC20(fromAsset).transferFrom(owner, address(this), amount);
        IERC20(fromAsset).approve(router, type(uint256).max);
        PathList memory optPath = pathOptimization[fromAsset][toAsset];
        if(optPath.path.length == 0) {
            revert("not set path");
        }

        IRouter(router).swapExactTokensForTokens(amount, 0, optPath.path, owner, block.timestamp*2);
        IERC20(fromAsset).approve(router, 0);
    }
}