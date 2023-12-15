// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

import "../IntentMarket/OrderMatchEngine.sol";

/// @title Constraints
/// @author windowhan (https://github.com/windowhan)
/// @notice If the App is a Contract that defines the execution logic of an Intent, then Constraints is a Contract that verifies the minimum conditions that must be met for the Intent to be executed.
/// @dev If the App is a Contract that defines the execution logic of an Intent, then Constraints is a Contract that verifies the minimum conditions that must be met for the Intent to be executed.
contract Constraints is Ownable {
    OrderMatchEngine public engine;
    uint8 public constant scoringType = 1;

    /// @notice setOrderMatchEngine
    /// @dev -
    /// @param target, The address of the OrderMatchEngine Contract
    function setOrderMatchEngine(address target) public onlyOwner{
        engine = OrderMatchEngine(target);
    }

    /// @notice getScoringType
    /// @dev -
    /// @return scoringType, The scoring type used in the OrderMatchEngine Contract.
    ///         0 - Winner determined by who submitted the order first.
    ///         1 - Winner calculated in ascending order of score.
    ///         2 - Winner calculated in descending order of score.
    function getScoringType() external view returns (uint8) {
        return scoringType;
    }

    /// @notice getScore
    /// @dev In the OrderMatchEngine, the value of the solutions provided by Solvers is represented numerically.
    /// @param constraints, It is the value that defines the minimum result that must be guaranteed after executing the intent.
    /// @param orderIntent, It is the content of the intent that the user wishes to execute.
    /// @return score Only scores calculated according to the ScoringType can be used properly with the OrderMatchEngine.
    function getScore(bytes calldata constraints, bytes calldata orderIntent) external view returns (uint256 score) {
        uint256 outputAmount = uint256(bytes32(constraints[52:84]));
        uint256 submitOutputAmount = uint256(bytes32(orderIntent[0:32]));
        return (submitOutputAmount-outputAmount);
    }

    /// @notice getPrevState
    /// @dev Use the getPrevState function to retrieve the state before the execution of the intent. Later, compare the state after the execution of the intent with the previous state to verify whether the minimum required conditions have been met.
    /// @param wallet, It is the address of the wallet that will execute the intent.
    /// @param constraints, It is the value that defines the minimum result that must be guaranteed after executing the intent.
    /// @return output, It is the previous state used to check whether the minimum required result has been achieved after the execution of the intent.
    function getPrevState(address wallet, bytes calldata constraints) external view returns (bytes memory) {
        address swapInputAsset = address(uint160(bytes20(constraints[32:52])));
        address swapOutputAsset = address(uint160(bytes20(constraints[84:104])));

        uint256 prevInputAssetBalance = IERC20(swapInputAsset).balanceOf(wallet);
        uint256 prevOutputAssetBalance = IERC20(swapOutputAsset).balanceOf(wallet);

        return abi.encode(prevInputAssetBalance, prevOutputAssetBalance);
    }


    /// @notice check
    /// @dev This function checks whether the minimum conditions desired by the user have been met by comparing the state before executing the intent with the state after its execution.
    /// @param wallet, It is the address of the wallet that will execute the intent.
    /// @param prevState, It is the previous state of the Intent required to verify the minimum result that must be guaranteed after the Intent has been executed.
    /// @param constraints, It is the value that defines the minimum result that must be guaranteed after executing the intent.
    /// @param orderIntent, It is the content of the intent that the user wishes to execute.
    /// @return result, This value signifies whether the minimum conditions desired by the user have been guaranteed by comparing the state before executing the intent with the state after its execution.
    function check(address wallet, bytes calldata prevState, bytes calldata constraints, bytes calldata orderIntent) external view returns (bool) {
        uint256 swapInput = uint256(bytes32(constraints[0:32]));
        address swapInputAsset = address(uint160(bytes20(constraints[32:52])));
        uint256 swapOutput = uint256(bytes32(constraints[52:84]));
        address swapOutputAsset = address(uint160(bytes20(constraints[84:104])));
        uint256 marketTiming = uint256(bytes32(constraints[104:136]));

        uint256 prevInputAssetBalance = uint256(bytes32(prevState[0:32]));
        uint256 prevOutputAssetBalance = uint256(bytes32(prevState[32:64]));

        address _wallet = wallet;
        uint256 afterInputAssetBalance = IERC20(swapInputAsset).balanceOf(_wallet);
        uint256 afterOutputAssetBalance = IERC20(swapOutputAsset).balanceOf(_wallet);

        uint256 inputAmount = prevInputAssetBalance - afterInputAssetBalance;
        uint256 outputAmount = afterOutputAssetBalance - prevOutputAssetBalance;
        uint256 submitOutputAmount = uint256(bytes32(orderIntent[0:32]));

        if(swapInput < inputAmount) {
            revert("too much input amount!!!");
        }

        if(swapOutput > submitOutputAmount) {
            revert("too little output amount!!!");
        }

        if(marketTiming > block.timestamp) {
            revert("not ready..");
        }
        return true;
    }
}