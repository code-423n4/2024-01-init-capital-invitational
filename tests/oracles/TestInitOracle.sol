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

contract TestInitOracle is Test {
    InitOracle public initOracle;

    address public constant PYTH_ARBITRUM = 0xff1a0f4744e8582DF1aE09D5611b887B6a12925C;
    address public constant MOCK_ADMIN = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant MOCK_TOKEN = 0xCAbAE6f6Ea1ecaB08Ad02fE02ce9A44F09aebfA2;

    function setUp() public {
        startHoax(MOCK_ADMIN);
        AccessControlManager accessControlManager = new AccessControlManager();
        ProxyAdmin proxyAdmin = new ProxyAdmin();
        accessControlManager.grantRole(keccak256('guardian'), MOCK_ADMIN);
        accessControlManager.grantRole(keccak256('governor'), MOCK_ADMIN);
        vm.stopPrank();

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
    }

    function _configInitOracleMock(
        address _token,
        uint _primaryPrice,
        bool _isPrimaryValid,
        uint _secondaryPrice,
        bool _isSecondaryValid,
        uint _maxPriceDeviationE18
    ) internal {
        IMockOracle primaryOracle;
        IMockOracle secondaryOracle;

        // setup a valid/invalid primary oracle
        if (_isPrimaryValid) {
            primaryOracle = new MockOracle(_primaryPrice);
        } else {
            primaryOracle = new MockInvalidOracle();
        }

        // setup a valid/invalid secondary oracle
        if (_isSecondaryValid) {
            secondaryOracle = new MockOracle(_secondaryPrice);
        } else {
            secondaryOracle = new MockInvalidOracle();
        }

        address[] memory tokens = new address[](1);
        tokens[0] = _token;
        address[] memory primaryOracles = new address[](1);
        primaryOracles[0] = address(primaryOracle);
        address[] memory secondaryOracles = new address[](1);
        secondaryOracles[0] = address(secondaryOracle);
        uint[] memory maxPriceDeviationsE18 = new uint[](1);
        maxPriceDeviationsE18[0] = _maxPriceDeviationE18;
        initOracle.setPrimarySources(tokens, primaryOracles);
        initOracle.setSecondarySources(tokens, secondaryOracles);
        initOracle.setMaxPriceDeviations_e18(tokens, maxPriceDeviationsE18);
    }

    function testInitOraclePrimaryAndSecondarySourceValid() public {
        startHoax(MOCK_ADMIN);
        _configInitOracleMock(MOCK_TOKEN, 3e32, true, 2e18, false, 1e18);
        vm.stopPrank();
        uint value = initOracle.getPrice_e36(MOCK_TOKEN);
        assertEq(value, 3e32);
    }

    function testInitOracleOnlyPrimarySourceValid() public {
        startHoax(MOCK_ADMIN);
        _configInitOracleMock(MOCK_TOKEN, 3e32, true, 0, false, 1e18);
        vm.stopPrank();
        uint value = initOracle.getPrice_e36(MOCK_TOKEN);
        assertEq(value, 3e32);
    }

    function testInitOracleOnlyPrimarySourceSet() public {
        startHoax(MOCK_ADMIN);
        IMockOracle primaryOracle;
        primaryOracle = new MockOracle(3e32);
        address[] memory tokens = new address[](1);
        tokens[0] = MOCK_TOKEN;
        address[] memory primaryOracles = new address[](1);
        primaryOracles[0] = address(primaryOracle);
        initOracle.setPrimarySources(tokens, primaryOracles);
        vm.stopPrank();

        uint value = initOracle.getPrice_e36(MOCK_TOKEN);
        assertEq(value, 3e32);
    }

    function testRevertInitOracleOnlySecondarySourceSet() public {
        startHoax(MOCK_ADMIN);
        IMockOracle secondaryOracle;
        secondaryOracle = new MockOracle(3e32);
        address[] memory tokens = new address[](1);
        tokens[0] = MOCK_TOKEN;
        address[] memory secondaryOracles = new address[](1);
        secondaryOracles[0] = address(secondaryOracle);
        initOracle.setSecondarySources(tokens, secondaryOracles);
        vm.stopPrank();
        // expectRevert PRIMARY_SOURCE_NOT_SET (#708)
        vm.expectRevert(bytes('#708'));
        initOracle.getPrice_e36(MOCK_TOKEN);
    }

    function testInitOracleOnlySecondarySourceValid() public {
        startHoax(MOCK_ADMIN);
        _configInitOracleMock(MOCK_TOKEN, 0, false, 3e32, true, 1e18);
        vm.stopPrank();
        uint value = initOracle.getPrice_e36(MOCK_TOKEN);
        assertEq(value, 3e32);
    }

    function testRevertInitOracleNoValidSource() public {
        startHoax(MOCK_ADMIN);
        _configInitOracleMock(MOCK_TOKEN, 0, false, 0, false, 1e18);
        vm.expectRevert(bytes('#700')); //NO_VALID_SOURCE
        initOracle.getPrice_e36(MOCK_TOKEN);
    }

    function testRevertTooMuchPriceDeviation() public {
        startHoax(MOCK_ADMIN);
        _configInitOracleMock(MOCK_TOKEN, 3e32, true, 2e32, true, 1e18);
        vm.stopPrank();
        vm.expectRevert(bytes('#701')); // TOO_MUCH_DEVIATION
        initOracle.getPrice_e36(MOCK_TOKEN);
    }

    function testRevertSetupTooLowMaxPriceDeviation() public {
        startHoax(MOCK_ADMIN);
        address[] memory tokens = new address[](1);
        tokens[0] = MOCK_TOKEN;
        uint[] memory maxPriceDeviationsE18 = new uint[](1);
        maxPriceDeviationsE18[0] = 9e17;

        vm.expectRevert(bytes('#702')); // TOO_LOW_MAX_PRICE_DEVIATION
        initOracle.setMaxPriceDeviations_e18(tokens, maxPriceDeviationsE18);
        vm.stopPrank();
    }
}
