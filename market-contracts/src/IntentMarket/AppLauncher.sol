// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./MarketRegistry.sol";
import "./Market.sol";

interface IApp {
    function main(bytes calldata args) external;
}

interface IContraints {
    function check(address wallet, bytes calldata prevState, bytes calldata conditions) external returns (bool);
    function getPrevState(address wallet, bytes calldata config) external view returns (bytes memory);
}

/// @notice AppLauncher
/// @author windowhan (https://github.com/windowhan)
contract AppLauncher {
    MarketRegistry public marketRegistry;
    Market public market;

    constructor(address _marketRegistry, address _market) {
        marketRegistry = MarketRegistry(_marketRegistry);
        market = Market(_market);
    }

    // @dev App을 실행시키기 위한 Loader 역할을 함. Intent 실행 이전에 사용자가 원하는 조건에 부합하는지 실행 이전의 조건을 수집하고 실행 이후의 조건을 수집한 뒤에 2개의 데이터를 대조해서 사용자가 원하는 조건에 부합했는지 검사함.
    // @param appId - MarketRegistry에 등록된 Intent Application의 ID
    // @param appArgs - Intent를 실행시키기 위해서 필요한 Argument // 이건 submitOrder로 받아야하고...
    // @param prevStateParseConfig - Intent 실행시키기 이전에 조건을 체크하기 위한 값들을 얻어오는데 필요한 Argument -> 이것도 openIntent로부터 받아야하고...
    // @param constraints - Intent 실행시킨 이후의 조건을 체크하기 위한 값들을 얻어오는데 필요한 Argument -> 이건 openIntent로부터 받아야하고....
    // 뭔가 appArgs, prevStateParseConfig, constraints를 OrderBook에다가 넣는것이 맞는거같기도?
    // +로 Best Execution 잘 지켜졌는지 체크해야함. 음
    // 위에 인자들 전부 다 OrderBook으로 넘기고 intentId만 run함수로 넘기면 될것같음
    function run(uint256 appId, bytes calldata appArgs, bytes calldata prevStateParseConfig, bytes calldata constraints) public {
        // OrderBook으로부터 winner인지 체크하는 것 필요.
        (address appAddr, address checkAddr) = marketRegistry.getAppExecutionInfo(appId);
        market.checkExpireSubscription(appId, msg.sender);
        bytes memory prevState = IContraints(checkAddr).getPrevState(msg.sender, prevStateParseConfig);
        IApp(appAddr).main(msg.sender, appArgs);
        if(IContraints(checkAddr).check(msg.sender, prevState, constraints)==false)
            revert("constraints violation!");
    }
}