// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';
import 'forge-std/console2.sol';

import {TransparentUpgradeableProxy} from '@openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from '@openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol';

import '../../contracts/common/library/InitErrors.sol';
import {AccessControlManager} from '../../contracts/common/AccessControlManager.sol';
import {InitOracle} from '../../contracts/oracle/InitOracle.sol';
import {Api3OracleReader} from '../../contracts/oracle/Api3OracleReader.sol';
import {PythOracleReader} from '../../contracts/oracle/PythOracleReader.sol';
import {IMockOracle, MockOracle, MockInvalidOracle} from '../mock/mockOracle.sol';

contract TestInitOracleFork is Test {
    InitOracle public initOracle;

    address public constant MOCK_ADMIN = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant MOCK_TOKEN = 0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2;

    // tokens
    address public constant WBTC_ARBITRUM = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address public constant WETH_ARBITRUM = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant USDT_ARBITRUM = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address public constant USDC_ARBITRUM = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant DAI_ARBITRUM = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    // Api3's data feed ids
    bytes32 public constant WBTC_DATAFEED_ID_ARBITRUM =
        0xac52520609232c9017425b98693770c2fd8f897774bdc9b7cf7cf9057cd5018b;
    bytes32 public constant ETH_DATAFEED_ID_ARBITRUM =
        0x21f45679484bf680658a4746ef60e81b1efbb9359a5973083e673815d423c072;
    bytes32 public constant USDT_DATAFEED_ID_ARBITRUM =
        0xff96db9f5eaf10f5425e58ceb282308ab8099ef73c01bc3c6a094f84fa0aa53d;
    bytes32 public constant USDC_DATAFEED_ID_ARBITRUM =
        0x811b12b44adf2e6ad84dc3ec577cc6c0b15e76e400764139330ce3fc58043d26;
    bytes32 public constant DAI_DATAFEED_ID_ARBITRUM =
        0x07bd5ed37a946e4c54f1efb26f013245406fbf760ded5db962a9ce054570aa28;
    address public constant API3_SERVER_1 = 0x3dEC619dc529363767dEe9E71d8dD1A5bc270D76;

    // Pyth's feed ids
    bytes32 public constant WBTC_PRICE_FEED_ID = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;
    bytes32 public constant ETH_PRICE_FEED_ID = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
    bytes32 public constant USDT_PRICE_FEED_ID = 0x2b89b9dc8fdf9f34709a5b106b472f0f39bb6ca9ce04b0fd7f2e971688e2e53b;
    bytes32 public constant USDC_PRICE_FEED_ID = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
    bytes32 public constant DAI_PRICE_FEED_ID = 0xb0948a5e5313200c632b51bb5ca32f6de0d36e9950a942d19751e833f70dabfd;
    address public constant PYTH_ARBITRUM = 0xff1a0f4744e8582DF1aE09D5611b887B6a12925C;

    // RPCs
    string public constant ARBITRUM_RPC_URL = 'https://arbitrum-one.publicnode.com';
    uint public arbitrumFork;

    function setUp() public {
        arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);
        vm.selectFork(arbitrumFork);
        startHoax(MOCK_ADMIN);
        _deployOnFork();
        vm.stopPrank();
    }

    function _deployOnFork() internal {
        AccessControlManager accessControlManager = new AccessControlManager();
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        accessControlManager.grantRole(keccak256('guardian'), MOCK_ADMIN);
        accessControlManager.grantRole(keccak256('governor'), MOCK_ADMIN);

        // Deploy PythReaderOracle's proxy and implementation
        PythOracleReader pythOracleReaderImpl = new PythOracleReader(address(accessControlManager));
        PythOracleReader pythOracleReader = PythOracleReader(
            address(
                new TransparentUpgradeableProxy(
                    address(pythOracleReaderImpl),
                    address(proxyAdmin),
                    abi.encodeWithSelector(pythOracleReaderImpl.initialize.selector, PYTH_ARBITRUM)
                )
            )
        );

        // Deploy api3ReaderOracle's proxy and implementation
        Api3OracleReader api3OracleReaderImpl = new Api3OracleReader(address(accessControlManager));
        Api3OracleReader api3OracleReader = Api3OracleReader(
            address(
                new TransparentUpgradeableProxy(
                    address(api3OracleReaderImpl),
                    address(proxyAdmin),
                    abi.encodeWithSelector(api3OracleReaderImpl.initialize.selector, API3_SERVER_1)
                )
            )
        );

        InitOracle initOracleImpl = new InitOracle(address(accessControlManager));
        initOracle = InitOracle(
            address(
                new TransparentUpgradeableProxy(
                    address(initOracleImpl),
                    address(proxyAdmin),
                    abi.encodeWithSelector(initOracleImpl.initialize.selector)
                )
            )
        );
        _configOnFork(api3OracleReader, pythOracleReader);
    }

    function _configOnFork(Api3OracleReader _api3OracleReader, PythOracleReader _pythOracleReader) internal {
        startHoax(MOCK_ADMIN);

        // tokens
        address[] memory tokens = new address[](5);
        tokens[0] = WBTC_ARBITRUM;
        tokens[1] = WETH_ARBITRUM;
        tokens[2] = USDC_ARBITRUM;
        tokens[3] = USDT_ARBITRUM;
        tokens[4] = DAI_ARBITRUM;

        // api3
        bytes32[] memory dataFeeds = new bytes32[](5);
        dataFeeds[0] = WBTC_DATAFEED_ID_ARBITRUM;
        dataFeeds[1] = ETH_DATAFEED_ID_ARBITRUM;
        dataFeeds[2] = USDC_DATAFEED_ID_ARBITRUM;
        dataFeeds[3] = USDT_DATAFEED_ID_ARBITRUM;
        dataFeeds[4] = DAI_DATAFEED_ID_ARBITRUM;
        uint[] memory api3MaxStaleTimes = new uint[](5);
        // note: max stale time test on another contract
        api3MaxStaleTimes[0] = type(uint).max;
        api3MaxStaleTimes[1] = type(uint).max;
        api3MaxStaleTimes[2] = type(uint).max;
        api3MaxStaleTimes[3] = type(uint).max;
        api3MaxStaleTimes[4] = type(uint).max;

        // pyth
        bytes32[] memory priceIds = new bytes32[](5);
        priceIds[0] = WBTC_PRICE_FEED_ID;
        priceIds[1] = ETH_PRICE_FEED_ID;
        priceIds[2] = USDC_PRICE_FEED_ID;
        priceIds[3] = USDT_PRICE_FEED_ID;
        priceIds[4] = DAI_PRICE_FEED_ID;
        uint[] memory pythMaxStaleTimes = new uint[](5);
        // note: max stale time and max confidential deviation
        // test on another contract
        pythMaxStaleTimes[0] = type(uint192).max;
        pythMaxStaleTimes[1] = type(uint192).max;
        pythMaxStaleTimes[2] = type(uint192).max;
        pythMaxStaleTimes[3] = type(uint192).max;
        pythMaxStaleTimes[4] = type(uint192).max;

        // configs
        _api3OracleReader.setDataFeedIds(tokens, dataFeeds);
        _api3OracleReader.setMaxStaleTimes(tokens, api3MaxStaleTimes);
        _pythOracleReader.setPriceIds(tokens, priceIds);
        _pythOracleReader.setMaxStaleTimes(tokens, pythMaxStaleTimes);
        uint tokenLength = tokens.length;
        address[] memory primarySources = new address[](tokenLength);
        address[] memory secondarySources = new address[](tokenLength);
        uint[] memory maxPriceDeviationsE18 = new uint[](tokenLength);
        for (uint i; i < tokenLength; ++i) {
            primarySources[i] = address(_api3OracleReader);
            secondarySources[i] = address(_pythOracleReader);
            maxPriceDeviationsE18[i] = 1e50;
        }
        initOracle.setPrimarySources(tokens, primarySources);
        initOracle.setSecondarySources(tokens, secondarySources);
        initOracle.setMaxPriceDeviations_e18(tokens, maxPriceDeviationsE18);
    }

    function testGetPriceBTC() public {
        // BTC price around 3.4385347e+32 [USDE36 per wei]
        // BTC price[USDE36 per wei] should be around 34e31 which is between 3e32 to 1e33
        uint value = initOracle.getPrice_e36(WBTC_ARBITRUM);
        assertGt(value, 3e32);
        assertLt(value, 1e33);
    }

    function testGetPriceETH() public {
        // ETH price around 1.7744132e+21 [USDE36 per wei]
        // ETH price[USDE36 per wei] should be around 18e20 which is between 1e21 to 1e22
        uint value = initOracle.getPrice_e36(WETH_ARBITRUM);
        assertGt(value, 1e21);
        assertLt(value, 1e22);
    }

    function testGetPriceUSDC() public {
        // USDC price aroun 1.0002872e+30 [USDE36 per wei]
        // USDC price[USDE36 per wei] should be around 1e30 which is between 99e28 to 11e29
        uint value = initOracle.getPrice_e36(USDC_ARBITRUM);
        assertGt(value, 99e28);
        assertLt(value, 11e29);
    }

    function testGetPriceUSDT() public {
        // USDT price aroun 1.0003083e+30 [USDE36 per wei]
        // USDT price[USDE36 per wei] should be around 1e30 which is between 99e28 to 11e29
        uint value = initOracle.getPrice_e36(USDT_ARBITRUM);
        assertGt(value, 99e28);
        assertLt(value, 11e29);
    }

    function testPriceDAI() public {
        // DAI price around 9.992e+17 [USDE36 per wei]
        // DAI price[USDE36 per wei] should be around 9.9e17 which is between 99e16 to 11e17
        uint value = initOracle.getPrice_e36(DAI_ARBITRUM);
        assertGt(value, 99e16);
        assertLt(value, 11e17);
    }
}
