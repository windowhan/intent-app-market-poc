// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "forge-std/console.sol";

    struct AppData {
        string appName;
        address appAddr;
        address checkAddr;
        string conditionJson;
        address creator;
        address wannaSecurityCouncil;
        uint8 securityCouncilPass;
        uint8 finalPass;
        uint8 payFlag;
        bytes prevAction;
        address paymentCurrency;
        uint128 price;
        uint48 usePeriod;
        string specificBundlerURL;
    }

contract MarketRegistry is Ownable{
    uint256 public appIndex;
    mapping(uint256=>AppData) public appInfo;
    mapping(address=>uint8) public securityCouncil;

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
        address wannaSecurityCouncil = appInfo[appId].wannaSecurityCouncil;
        if(msg.sender!=wannaSecurityCouncil && securityCouncil[msg.sender]!=1){
            revert("not proper security council..");
        }
        _;
    }

    function registerAppMetadata(string calldata appName, address intentApp, address checkAddr, string memory conditionJson, address wannaSecurityCouncil, uint8 payFlag, address paymentCurrency, uint128 price, uint48 usePeriod, string calldata specificBundlerURL, bytes calldata approveAsset) public returns (uint256 appId){
        AppData memory appdata;
        appdata.appName = appName;
        appdata.appAddr = intentApp;
        appdata.checkAddr = checkAddr;
        appdata.conditionJson = conditionJson;
        appdata.securityCouncilPass = 0;
        appdata.finalPass = 0;
        appdata.creator = msg.sender;
        appdata.wannaSecurityCouncil = wannaSecurityCouncil;

        appdata.payFlag = payFlag;
        appdata.paymentCurrency = paymentCurrency;
        appdata.price = price;
        appdata.usePeriod = usePeriod;
        appdata.approveAsset = approveAsset;
        appdata.specificBundlerURL = specificBundlerURL;
        console.log("appdata.specificBundlerURL : %s", appdata.specificBundlerURL);

        appInfo[appIndex] = appdata;
        appIndex += 1;
        return appIndex-1;
    }

    function updateAppMetadata(uint128 appId, string calldata appName, address intentApp, address checkAddr, string memory conditionJson, address wannaSecurityCouncil, uint8 payFlag, address paymentCurrency, uint128 price, uint48 usePeriod, string calldata specificBundlerURL, bytes calldata approveAsset) public onlyCreatorBeforePass(appId){
        AppData memory appdata = appInfo[appId];

        appdata.appName = appName;
        appdata.appAddr = intentApp;
        appdata.checkAddr = checkAddr;
        appdata.conditionJson = conditionJson;

        appdata.payFlag = payFlag;
        appdata.paymentCurrency = paymentCurrency;
        appdata.price = price;
        appdata.usePeriod = usePeriod;
        appdata.approveAsset = approveAsset;
        appdata.specificBundlerURL = specificBundlerURL;

        appInfo[appId] = appdata;
    }

    /*
        SecurityCouncil Part
    */
    function approveSecurityCouncil(uint256 appId) public onlySecurityConcil(appId) {
        appInfo[appId].securityCouncilPass = 1;
    }

    function revokeSecurityCouncil(uint256 appId) public onlySecurityConcil(appId) {
        appInfo[appId].securityCouncilPass = 0;
    }


    /*
        Admin Part
    */
    function superUpdateOnlyAdmin(uint256 appId, string calldata appName, address intentApp, address checkAddr, string memory conditionJson, uint8 securityCouncilPass, uint8 finalPass, uint8 payFlag, address paymentCurrency, uint128 price, uint48 usePeriod, string calldata specificBundlerURL, bytes calldata approveAsset) public onlyOwner {
        appInfo[appId].appName = appName;
        appInfo[appId].appAddr = intentApp;
        appInfo[appId].checkAddr = checkAddr;
        appInfo[appId].conditionJson = conditionJson;

        appInfo[appId].payFlag = payFlag;
        appInfo[appId].paymentCurrency = paymentCurrency;
        appInfo[appId].price = price;
        appInfo[appId].usePeriod = usePeriod;

        appInfo[appId].securityCouncilPass = securityCouncilPass;
        appInfo[appId].finalPass = finalPass;

        appdata.approveAsset = approveAsset;
        appdata.specificBundlerURL = specificBundlerURL;
    }

    function approveFinalPass(uint256 appId) public onlyOwner {
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
