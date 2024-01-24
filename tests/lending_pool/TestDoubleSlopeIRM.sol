// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';
import {DoubleSlopeIRM} from '../../contracts/lending_pool/DoubleSlopeIRM.sol';

contract TestDoubleSlopIRM is Test {
    uint constant MAX_UTIL_E18 = 1e18;

    DoubleSlopeIRM doubleSlopIRM;
    uint baseBorrowRate_e18;
    uint jumpUtil_e18;
    uint borrRateMultiplier_e18;
    uint jumpMultiplier_e18;

    function setUp() public {
        baseBorrowRate_e18 = 0.0001e18; // 0.0001%
        jumpUtil_e18 = 0.75e18; // 75%
        borrRateMultiplier_e18 = 0.5e18; // m1
        jumpMultiplier_e18 = 0.8e18; // m2
        doubleSlopIRM = new DoubleSlopeIRM(baseBorrowRate_e18, jumpUtil_e18, borrRateMultiplier_e18, jumpMultiplier_e18);
    }

    function testBorrRateNoUtil(uint _cash) public {
        uint borrowRate_e18 = doubleSlopIRM.getBorrowRate_e18(_cash, 0);

        assertEq(borrowRate_e18, baseBorrowRate_e18);

        // logs
        console2.log('Base Borrow Rate: ', baseBorrowRate_e18);
        console2.log('Actual Borrow Rate: ', borrowRate_e18);
    }

    function testBorrRateUtilBelowJumpUtil(uint _debt) public {
        uint cash = 1e18 - jumpUtil_e18;
        _debt = bound(_debt, 0, jumpUtil_e18);

        uint totalAsset = cash + _debt;
        uint utilization_e18 = (_debt * 1e18) / totalAsset;

        // baseRate + m1 * utilization
        uint calculateBorrowRate_e18 = baseBorrowRate_e18 + (borrRateMultiplier_e18 * utilization_e18) / 1e18;
        uint actualBorrowRate_e18 = doubleSlopIRM.getBorrowRate_e18(cash, _debt);

        assertEq(actualBorrowRate_e18, calculateBorrowRate_e18);

        // logs
        console2.log('Util', utilization_e18);
        console2.log('Calculate Borrow Rate: ', calculateBorrowRate_e18);
        console2.log('Actual Borrow Rate: ', actualBorrowRate_e18);
    }

    function testBorrRateUtilOverJumpUtil(uint _cash) public {
        _cash = bound(_cash, 0, 1e18 - jumpUtil_e18);
        uint debt = jumpUtil_e18;

        uint totalAsset = _cash + debt;
        uint utilization_e18 = (debt * 1e18) / totalAsset;

        // baseRate + m1 * jumpUtil + m2 * (util - jumpUtil)
        uint calculateBorrowRate_e18 = baseBorrowRate_e18
            + (borrRateMultiplier_e18 * jumpUtil_e18 + jumpMultiplier_e18 * (utilization_e18 - jumpUtil_e18)) / 1e18;

        uint actualBorrowRate_e18 = doubleSlopIRM.getBorrowRate_e18(_cash, debt);

        assertEq(actualBorrowRate_e18, calculateBorrowRate_e18);

        // logs
        console2.log('Util', utilization_e18);
        console2.log('Calculate Borrow Rate: ', calculateBorrowRate_e18);
        console2.log('Actual Borrow Rate: ', actualBorrowRate_e18);
    }

    function testBorrowRateMaxUtil() public {
        // baseRate + m1 * jumpUtil + m2 * (max_util - jumpUtil)
        uint calculateBorrowRate_e18 = baseBorrowRate_e18
            + (borrRateMultiplier_e18 * jumpUtil_e18 + jumpMultiplier_e18 * (MAX_UTIL_E18 - jumpUtil_e18)) / 1e18;
        uint actualBorrowRate_e18 = doubleSlopIRM.getBorrowRate_e18(0, 1e18);

        assertEq(actualBorrowRate_e18, calculateBorrowRate_e18);

        // logs
        console2.log('Calculate Borrow Rate: ', calculateBorrowRate_e18);
        console2.log('Actual Borrow Rate: ', actualBorrowRate_e18);
    }

    function testBorrowRatePrecalculation() public {
        // baseBorrowRate_e18 = 0.0001e18; // 0.0001%
        // jumpUtil_e18 = 0.75e18; // 75%
        // borrRateMultiplier_e18 = 0.5e18; // m1
        // jumpMultiplier_e18 = 0.8e18; // m2
        // cash:  200e18
        // borrow:  800e18
        // total asset = 200 + 800 = 1,000e18
        // util = 8000 / 1,000 = 80%

        uint actualBorrowRate_e18 = doubleSlopIRM.getBorrowRate_e18(200e18, 800e18);

        // baseRate + m1 * jumpUtil + m2 * (util - jumpUtil)
        // borrow rate = 0.0001 + 0.5 * 0.75 + 0.8 * ( 0.8 - 0.75) = 0.0001 + 0.375 + 0.04
        // 0.4151
        assertApproxEqAbs(actualBorrowRate_e18, 0.4151e18, 0.00001e18);

        // logs
        console2.log('Actual Borrow Rate: ', actualBorrowRate_e18);
    }
}
