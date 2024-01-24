// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';
import 'forge-std/console2.sol';

import {TransparentUpgradeableProxy} from '@openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from '@openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol';

import {AccessControlManager} from '../../contracts/common/AccessControlManager.sol';
import {Api3OracleReader} from '../../contracts/oracle/Api3OracleReader.sol';
import {IMockOracle, MockOracle, MockInvalidOracle} from '../mock/mockOracle.sol';

contract TestApi3OracleReader is Test {
    Api3OracleReader public api3OracleReader;

    address public constant MOCK_ADMIN = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant MOCK_TOKEN = 0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2;
    address public constant WBTC_ARBITRUM = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

    // Api3's data feed ids
    bytes32 public constant WBTC_DATAFEED_ID_ARBITRUM =
        0xac52520609232c9017425b98693770c2fd8f897774bdc9b7cf7cf9057cd5018b;
    address public constant API3_SERVER_1 = 0x3dEC619dc529363767dEe9E71d8dD1A5bc270D76;

    // rpc
    string public constant ARBITRUM_RPC_URL = 'https://arbitrum-one.publicnode.com';
    uint public arbitrumFork;

    function setUp() public {
        arbitrumFork = vm.createFork(ARBITRUM_RPC_URL);
        vm.selectFork(arbitrumFork);
        startHoax(MOCK_ADMIN);
        AccessControlManager accessControlManager = new AccessControlManager();
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        accessControlManager.grantRole(keccak256('guardian'), MOCK_ADMIN);
        accessControlManager.grantRole(keccak256('governor'), MOCK_ADMIN);

        Api3OracleReader api3OracleReaderImpl = new Api3OracleReader(address(accessControlManager));
        api3OracleReader = Api3OracleReader(
            address(
                new TransparentUpgradeableProxy(
                    address(api3OracleReaderImpl),
                    address(proxyAdmin),
                    abi.encodeWithSelector(api3OracleReaderImpl.initialize.selector, API3_SERVER_1)
                )
            )
        );
    }

    function testSetApi3ServerV1() public {
        address newApi3ServerV1 = 0x3dEC619dc529363767dEe9E71d8dD1A5bc270D76;
        api3OracleReader.setApi3ServerV1(newApi3ServerV1);
        address currentApi3ServerV1 = api3OracleReader.api3ServerV1();

        assertEq(currentApi3ServerV1, newApi3ServerV1);

        //logs
        console2.log('Current Api3ServerV1 address', currentApi3ServerV1);
    }

    function testSetDataFeedIdNotMatchLength() public {
        // configs
        address[] memory tokens = new address[](1);
        tokens[0] = WBTC_ARBITRUM;
        bytes32[] memory dataFeeds = new bytes32[](2);
        dataFeeds[0] = WBTC_DATAFEED_ID_ARBITRUM;
        dataFeeds[1] = WBTC_DATAFEED_ID_ARBITRUM;

        vm.expectRevert(bytes('#200')); // ARRAY_LENGTH_MISMATCHED

        api3OracleReader.setDataFeedIds(tokens, dataFeeds);
    }

    function testSetMaxStaleTimeNotMatchLength() public {
        // configs
        address[] memory tokens = new address[](1);
        tokens[0] = WBTC_ARBITRUM;
        uint[] memory maxStaleTimes = new uint[](2);
        maxStaleTimes[0] = 1;
        maxStaleTimes[1] = 1;

        vm.expectRevert(bytes('#200')); // ARRAY_LENGTH_MISMATCHED
        api3OracleReader.setMaxStaleTimes(tokens, maxStaleTimes);
    }

    function testDataFeedIdNotSet() public {
        vm.expectRevert(bytes('#705')); // DATAFEED_ID_NOT_SET
        api3OracleReader.getPrice_e36(WBTC_ARBITRUM);
    }

    function testMaxTimeStaleNotSet() public {
        // configs
        address[] memory tokens = new address[](1);
        tokens[0] = WBTC_ARBITRUM;
        bytes32[] memory dataFeeds = new bytes32[](1);
        dataFeeds[0] = WBTC_DATAFEED_ID_ARBITRUM;

        api3OracleReader.setDataFeedIds(tokens, dataFeeds);

        vm.expectRevert(bytes('#706')); // MAX_STALETIME_NOT_SET
        api3OracleReader.getPrice_e36(WBTC_ARBITRUM);
    }

    function testMaxStaleTimeExceeded() public {
        // configs
        address[] memory tokens = new address[](1);
        tokens[0] = WBTC_ARBITRUM;
        bytes32[] memory dataFeeds = new bytes32[](1);
        dataFeeds[0] = WBTC_DATAFEED_ID_ARBITRUM;
        uint[] memory maxStaleTimes = new uint[](1);
        maxStaleTimes[0] = 1;

        api3OracleReader.setDataFeedIds(tokens, dataFeeds);
        api3OracleReader.setMaxStaleTimes(tokens, maxStaleTimes);

        vm.expectRevert(bytes('#707')); // MAX_STALETIME_EXCEEDED
        api3OracleReader.getPrice_e36(WBTC_ARBITRUM);
    }
}
