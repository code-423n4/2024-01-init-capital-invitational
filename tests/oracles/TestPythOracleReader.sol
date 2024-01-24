// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';
import 'forge-std/console2.sol';

import {TransparentUpgradeableProxy} from '@openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {ProxyAdmin} from '@openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol';

import {AccessControlManager} from '../../contracts/common/AccessControlManager.sol';
import {PythOracleReader} from '../../contracts/oracle/PythOracleReader.sol';

// import {IMockOracle, MockOracle, MockInvalidOracle} from '../mock/mockOracle.sol';

contract TestPythOracleReader is Test {
    PythOracleReader public pythOracleReader;

    address public constant MOCK_ADMIN = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant MOCK_TOKEN = 0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2;
    address public constant WBTC_ARBITRUM = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

    // Pyth's feed ids
    bytes32 public constant WBTC_PRICE_FEED_ID = 0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;
    address public constant PYTH_ARBITRUM = 0xff1a0f4744e8582DF1aE09D5611b887B6a12925C;

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

        // Deploy PythReaderOracle's proxy and implementation
        PythOracleReader pythOracleReaderImpl = new PythOracleReader(address(accessControlManager));
        pythOracleReader = PythOracleReader(
            address(
                new TransparentUpgradeableProxy(
                    address(pythOracleReaderImpl),
                    address(proxyAdmin),
                    abi.encodeWithSelector(pythOracleReaderImpl.initialize.selector, PYTH_ARBITRUM)
                )
            )
        );
    }

    function testSetPyth() public {
        address newPyth = 0x3dEC619dc529363767dEe9E71d8dD1A5bc270D76;
        pythOracleReader.setPyth(newPyth);
        address currentPyth = pythOracleReader.pyth();

        assertEq(currentPyth, newPyth);

        //logs
        console2.log('Current Pyth Address', currentPyth);
    }

    function testSetPriceIdNotMatchLength() public {
        // // configs
        address[] memory tokens = new address[](1);
        tokens[0] = WBTC_ARBITRUM;
        bytes32[] memory priceIds = new bytes32[](2);
        priceIds[0] = WBTC_PRICE_FEED_ID;
        priceIds[1] = WBTC_PRICE_FEED_ID;

        vm.expectRevert(bytes('#200')); // ARRAY_LENGTH_MISMATCHED
        pythOracleReader.setPriceIds(tokens, priceIds);
    }

    function testSetMaxStaletimesNotMatchLength() public {
        // configs
        address[] memory tokens = new address[](1);
        tokens[0] = WBTC_ARBITRUM;
        uint[] memory pythMaxStaleTimes = new uint[](2);
        pythMaxStaleTimes[0] = type(uint192).max;
        pythMaxStaleTimes[1] = type(uint192).max;

        vm.expectRevert(bytes('#200')); // ARRAY_LENGTH_MISMATCHED
        pythOracleReader.setMaxStaleTimes(tokens, pythMaxStaleTimes);
    }

    function testPriceIdNotSet() public {
        vm.expectRevert(bytes('#703')); // NO_PRICE_ID
        pythOracleReader.getPrice_e36(WBTC_ARBITRUM);
    }

    function testMaxTimeStaleNotSet() public {
        // configs
        address[] memory tokens = new address[](1);
        tokens[0] = WBTC_ARBITRUM;
        bytes32[] memory priceIds = new bytes32[](1);
        priceIds[0] = WBTC_PRICE_FEED_ID;
        pythOracleReader.setPriceIds(tokens, priceIds);

        vm.expectRevert(bytes('#706')); // MAX_STALETIME_NOT_SET
        pythOracleReader.getPrice_e36(WBTC_ARBITRUM);
    }

    function testMaxStaleTimeExceeded() public {
        // configs
        address[] memory tokens = new address[](1);
        tokens[0] = WBTC_ARBITRUM;
        bytes32[] memory priceIds = new bytes32[](1);
        priceIds[0] = WBTC_PRICE_FEED_ID;
        uint[] memory pythMaxStaleTimes = new uint[](1);
        pythMaxStaleTimes[0] = 1;

        pythOracleReader.setPriceIds(tokens, priceIds);
        pythOracleReader.setMaxStaleTimes(tokens, pythMaxStaleTimes);

        vm.expectRevert(bytes('#707')); // MAX_STALETIME_EXCEEDED
        pythOracleReader.getPrice_e36(WBTC_ARBITRUM);
    }
}
