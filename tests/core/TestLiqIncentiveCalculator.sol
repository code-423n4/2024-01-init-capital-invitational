// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';

import {TransparentUpgradeableProxy} from '@openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

import {AccessControlManager} from '../../contracts/common/AccessControlManager.sol';
import {LiqIncentiveCalculator} from '../../contracts/core/LiqIncentiveCalculator.sol';
import '../helper/DeployAll.sol';

contract TestIncentiveCalculator is DeployAll {
    function testHealthyFactorGreaterEq1(uint _healthFactor_e18) public {
        vm.assume(_healthFactor_e18 >= 1e18);
        uint16 mode = 1;
        address repayToken = WETH;
        address collToken = USDT;

        uint multiplier =
            incentiveCalculator.getLiqIncentiveMultiplier_e18(mode, _healthFactor_e18, repayToken, collToken);

        // check conditions
        assertEq(multiplier, 1e18);
    }

    function testHealthFactorInRange(uint _healthFactor_e18) public {
        _healthFactor_e18 = _bound(_healthFactor_e18, 1, 1e18 - 1);
        uint16 mode = 1;
        address repayToken = WETH;
        address collToken = USDT;

        uint multiplier =
            incentiveCalculator.getLiqIncentiveMultiplier_e18(mode, _healthFactor_e18, repayToken, collToken);

        uint maxIncentiveCapped = incentiveCalculator.maxLiqIncentiveMultiplier_e18();

        // check conditions
        assertLe(multiplier, maxIncentiveCapped);
        assertGe(multiplier, 1e18); // when health factor is close to one, is possible to round the incentive down
    }

    function testWithPrecalculation() public {
        // max incentive multiplier: 1.3e18
        // mode: 1
        // mode incentive multiplier: 1e18
        // token incentive multiplier: Max(0.3, 0.5) = 0.5

        uint maxLiqIncentiveMultiplier_e18 = 1.3e18;
        uint16[] memory modes = new uint16[](1);
        modes[0] = 1;
        uint[] memory modeIncentiveMultipliers = new uint[](1);
        modeIncentiveMultipliers[0] = 1e18;
        address[] memory tokens = new address[](2);
        tokens[0] = WETH;
        tokens[1] = USDT;
        uint[] memory tokenIncentiveMultipliers_e18 = new uint[](2);
        tokenIncentiveMultipliers_e18[0] = 0.3e18;
        tokenIncentiveMultipliers_e18[1] = 0.5e18;

        _setConfig(
            maxLiqIncentiveMultiplier_e18, modes, modeIncentiveMultipliers, tokens, tokenIncentiveMultipliers_e18
        );

        uint healthFactor_e18 = 0.9e18;

        uint multiplier = incentiveCalculator.getLiqIncentiveMultiplier_e18(1, healthFactor_e18, USDT, WETH);

        // check conditions
        // multiplier = 1 + (1/0.9 -1) * 1 * 0.5 = 1 + (1.11-1)10.5 = 1.05555..
        assertApproxEqAbs(multiplier, 1.055e18, 1e15);
    }

    function _setConfig(
        uint _maxLiqIncentiveMultiplier_e18,
        uint16[] memory _modes,
        uint[] memory _modeIncentiveMultipliers_e18,
        address[] memory _tokens,
        uint[] memory _tokenIncentiveMultipliers_e18
    ) public {
        startHoax(ADMIN);
        incentiveCalculator.setMaxLiqIncentiveMultiplier_e18(_maxLiqIncentiveMultiplier_e18);
        incentiveCalculator.setModeLiqIncentiveMultiplier_e18(_modes, _modeIncentiveMultipliers_e18);
        incentiveCalculator.setTokenLiqIncentiveMultiplier_e18(_tokens, _tokenIncentiveMultipliers_e18);
        vm.stopPrank();
    }
}
