// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "forge-std/console.sol";

struct AppData {
    string appName;
    address appAddr;
    address checkAddr;
    string uiMetaJson;
    address creator;
    address approveSecurityCouncil;
    uint8 securityCouncilPass;
    uint8 finalPass;
    uint8 payFlag;
    address paymentCurrency;
    uint128 price;
    uint48 usePeriod;
    string description;
    address[] whitelistExecutor;
}

/// @title MarketRegistry
/// @author windowhan (https://github.com/windowhan)
/// @notice -
/// @dev -
contract MarketRegistry is Ownable{
    uint256 public appIndex;
    mapping(uint256=>AppData) public appInfo;
    mapping(uint256=>uint256) public recentUpdateTime;
    mapping(address=>uint8) public securityCouncil;

    uint256 constant public updateDelay = 3600;

    modifier onlyCreatorBeforePass(uint256 appId) {
        AppData memory appdata = appInfo[appId];
        address creator = appdata.creator;
        if(msg.sender!=creator){
            revert("only creator please");
        }

        if(appdata.finalPass == 1 || appdata.securityCouncilPass == 1) {
            revert("more update is impossible!");
        }
        _;
    }

    modifier onlySecurityConcil(uint256 appId) {
        address auditFirm = appInfo[appId].approveSecurityCouncil;
        if(msg.sender!=auditFirm && securityCouncil[msg.sender]!=1){
            revert("not proper security council..");
        }
        _;
    }


    /// @notice Registers a new app with its metadata.
    /// @param adParam The metadata for the app being registered.
    /// @return appId The ID assigned to the newly registered app.
    function registerAppMetadata(AppData memory adParam) public returns (uint256 appId){
        if(adParam.creator!=msg.sender)
            revert("creator should be same for msg.sender");
        adParam.finalPass = 0;
        adParam.securityCouncilPass = 0;
        appInfo[appIndex] = adParam;
        recentUpdateTime[appIndex] = block.timestamp;
        appIndex += 1;
        return appIndex-1;
    }

    /// @notice Updates the metadata of an existing registration proposal.
    /// @param appId The ID of the app to update.
    /// @param adParam The new metadata for the app.
    function updateAppMetadata(uint128 appId, AppData memory adParam) public onlyCreatorBeforePass(appId){
        AppData memory originalData = appInfo[appId];
        if(adParam.creator!=msg.sender)
            revert("creator should be same for msg.sender");
        if(recentUpdateTime[appIndex] + updateDelay > block.timestamp)
            revert("updateDelay is not passed..");
        require(originalData.finalPass!=0 && originalData.securityCouncilPass!=0);
        adParam.finalPass = originalData.finalPass;
        adParam.securityCouncilPass = originalData.securityCouncilPass;

        recentUpdateTime[appIndex] = block.timestamp;
        appInfo[appId] = adParam;
    }

    /// @notice approve app by security council
    /// @param appId The ID of the app to approve by security council.
    function approveSecurityCouncil(uint256 appId) public onlySecurityConcil(appId) {
        if(recentUpdateTime[appId] + updateDelay > block.timestamp)
            revert("updateDelay is not passed..");
        appInfo[appId].securityCouncilPass = 1;
    }

    /// @notice revoke app by security council
    /// @param appId The ID of the app to revoke by security council.
    function revokeSecurityCouncil(uint256 appId) public onlySecurityConcil(appId) {
        appInfo[appId].securityCouncilPass = 0;
        recentUpdateTime[appId] = block.timestamp;
    }

    function superUpdateOnlyAdmin(uint256 appId, AppData memory adParam) public onlyOwner {
        recentUpdateTime[appId] = block.timestamp;
        appInfo[appId] = adParam;
    }

    function approveFinalPass(uint256 appId) public onlyOwner {
        if(recentUpdateTime[appId] + updateDelay > block.timestamp)
            revert("updateDelay is not passed..");
        appInfo[appId].finalPass = uint8(1);
    }

    function revokeFinalPass(uint256 appId) public onlyOwner {
        appInfo[appId].finalPass = uint8(0);
    }

    function registerSecurityCouncil(address candidate) public onlyOwner {
        securityCouncil[candidate] = uint8(1);
    }

    function revokeSecurityCouncil(address candidate) public onlyOwner {
        securityCouncil[candidate] = uint8(0);
    }

    function getAppMetadata(uint256 appId) public view returns (AppData memory){
        if(appInfo[appId].finalPass == 0 || appInfo[appId].securityCouncilPass == 0) {
            revert("need finalPass and securityCouncilPass");
        }
        return appInfo[appId];
    }

    function getAppExecutionInfo(uint256 appId) public view returns (address, address) {
        AppData memory appdata = appInfo[appId];
        return (appdata.appAddr, appdata.checkAddr);
    }

    function getAppPaymentInfo(uint256 appId) public view returns (uint8, address, uint128, uint48, address) {
        AppData memory appdata = appInfo[appId];
        return (appdata.payFlag, appdata.paymentCurrency, appdata.price, appdata.usePeriod, appdata.creator);
    }
}
