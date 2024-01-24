// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract Constants {
    // -------- constants --------
    address public constant ADMIN = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant ALICE = address(0xA11CE);
    address public constant BOB = address(0xB0B);
    address public constant BEEF = address(0xBEEF);
    address public constant TREASURY = 0x749C67287353b78d7206A2c185816FA2154e7950;
    uint public constant RESERVE_FACTOR_E18 = 0.001e18; // 0.01%

    // tokens
    address public constant WBTC = 0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2;
    address public constant WETH = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111;
    address public constant USDC = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9;
    address public constant USDT = 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE;
    address public constant WMNT = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;
    address public constant mUSD = 0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3;
    address public constant USDY = 0x5bE26527e817998A7206475496fDE1E68957c5A6;

    // api3
    address public constant API3_SERVER_1 = 0x3dEC619dc529363767dEe9E71d8dD1A5bc270D76;
    bytes32 public constant WBTC_DATA_FEED_ID = 0x00cedbef5abf34213e8e7dd47f44e1f3a2b0c9d923e9391246ec25d4f34fcfaa;
    bytes32 public constant ETH_DATA_FEED_ID = 0x4385954e058fbe6b6a744f32a4f89d67aad099f8fb8b23e7ea8dd366ae88151d;
    bytes32 public constant USDC_DATA_FEED_ID = 0x811b12b44adf2e6ad84dc3ec577cc6c0b15e76e400764139330ce3fc58043d26; // no data yet in API3
    bytes32 public constant USDT_DATA_FEED_ID = 0xff96db9f5eaf10f5425e58ceb282308ab8099ef73c01bc3c6a094f84fa0aa53d; // no data yet in API3
    bytes32 public constant MNT_DATA_FEED_ID = 0x076b64e40200c66e74ea48009adf12fcce243beb12d39fa214ccf7c5ebd5e11e; // no data yet in API3
    // pyth
    address constant PYTH_MANTLE = 0xA2aa501b19aff244D90cc15a4Cf739D2725B5729;
    bytes32 public constant WBTC_PRICE_FEED_ID = 0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33;
    bytes32 public constant ETH_PRICE_FEED_ID = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
    bytes32 public constant USDC_PRICE_FEED_ID = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
    bytes32 public constant USDT_PRICE_FEED_ID = 0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b;
    bytes32 public constant MNT_PRICE_FEED_ID = 0x4e3037c822d852d79af3ac80e35eb420ee3b870dca49f9344a38ef4773fb0585;

    // position manager
    string public constant TOKEN_NAME = 'INIT';
    string public constant TOKEN_SYMBOL = 'INIT';
    uint8 public constant MAX_COLL_COUNT = 5;

    // incentive calculator
    uint public constant MAX_INCENTIVE_MULTIPLIER_E18 = 1.2e18;

    // fix rate IRM
    uint public constant FIXED_INTEREST_RATE_E18 = 0.0001e18; //0.0001%

    // double slop IRM
    uint public constant BASE_BORR_RATE_E18 = 0.0001e18; // rate per second
    uint public constant BORR_RATE_MULTIPLIER_E18 = 0.75e18; // m1
    uint public constant JUMP_UTIL_E18 = 0.5e18; // utilization at which the BORROW_RATE_M2 is applied
    uint public constant JUMP_MULTIPLIER_E18 = 0.8e18; // m2

    // plugins
    address public constant SWAP_ROUTER_V2 = 0xDd0840118bF9CCCc6d67b2944ddDfbdb995955FD;
    address public constant WETH_USDT_UNI_V2 = 0x545c3e7C17891b5AD450cb3A2C3F78D310Bbc243;
    address public constant FUSION_X_V2_FACTORY = 0xE5020961fA51ffd3662CDf307dEf18F9a87Cce7c;

    address public constant MOE_MASTER_CHEF = 0xA756f7D419e1A5cbd656A438443011a7dE1955b5;
    address public constant MOE_FACTORY = 0x5bEf015CA9424A7C07B68490616a4C1F094BEdEc;
    address public constant WETH_USDC_MOE = 0x33B1d7CfFf71BBa9DD987f96AD57e0A5f7Db9Ac5;
}
