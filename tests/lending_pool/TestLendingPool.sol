// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '../helper/DeployAll.sol';
import {PoolConfig} from '../../contracts/interfaces/core/IConfig.sol';
import {ILendingPool} from '../../contracts/interfaces/lending_pool/ILendingPool.sol';
import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';
import {IERC20Metadata} from '@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {IWNative} from '../../contracts/interfaces/common/IWNative.sol';
import {PythOracleReader} from '../../contracts/oracle/PythOracleReader.sol';
import {MockFixedRateIRM} from '../../contracts/mock/MockFixedRateIRM.sol';

contract TestLendingPool is DeployAll {
    address private constant mUSD_WHALE = 0x9FceDEd3a0c838d1e73E88ddE466f197DF379f70;

    struct PoolInfo {
        uint sharePrice;
        uint totalSupply;
        uint totalAssets;
        uint cash;
        uint underlyingBalance;
    }

    struct BorrowInfo {
        uint cash;
        uint totalAssets;
        uint totalDebt;
        uint totalDebtShares;
        uint underlyingBalance;
        uint debtPrice;
    }

    function testDecimals() public {
        address[5] memory tokens = [WETH, WBTC, WMNT, USDT, USDY];
        for (uint i = 0; i < tokens.length; ++i) {
            assertEq(lendingPools[tokens[i]].decimals(), IERC20Metadata(tokens[i]).decimals() + 8);
        }
    }

    function testLendingPoolSetter() public {
        vm.startPrank(ADMIN);
        uint reserveFactor = 0.002e18; //0.02%
        lendingPools[WETH].setReserveFactor_e18(reserveFactor);
        assertEq(lendingPools[WETH].reserveFactor_e18(), reserveFactor);
        lendingPools[WETH].setTreasury(BEEF);
        assertEq(lendingPools[WETH].treasury(), BEEF);
        vm.stopPrank();
    }

    function testMintNative(uint _amount) public {
        // assume the positon size is 10e6 dollar
        // token price is 10e-6 and the token decimals is 1e18
        // the worst amt possible is arount 1e30
        _amount = bound(_amount, 1, 1e29);
        _mintPool(address(initCore), WMNT, _amount);
    }

    function testMintERC20(uint _amount) public {
        _amount = bound(_amount, 1, 1e29);
        _mintPool(address(initCore), WBTC, _amount);
    }

    function testMintUSDY(uint _amount) public {
        uint whaleBalance = IERC20(mUSD).balanceOf(mUSD_WHALE);
        _amount = bound(_amount, 100, whaleBalance);
        _approveToken(mUSD_WHALE, mUSD, type(uint).max);
        _wrapRebase(mUSD_WHALE, mUSD, USDY, _amount, address(initCore), address(musdusdyWrapHelper));
        _mintPool(address(initCore), USDY, _amount);
    }

    function testMintUSDYRevert() public {
        // too low mUSD to USDY might result to 0 USDY (the amount is less than the denominator)
        _approveToken(mUSD_WHALE, mUSD, type(uint).max);
        vm.expectRevert(bytes('#103')); // multicall fails -> transfer 0 share, couldn't unwrap

        _wrapRebase(mUSD_WHALE, mUSD, USDY, 1, address(initCore), address(musdusdyWrapHelper));
    }

    function testMintSameAmount(uint _amount) public {
        _amount = bound(_amount, 1, 1e29);
        uint share1 = _mintPool(address(initCore), WBTC, _amount);
        uint share2 = _mintPool(address(initCore), WBTC, _amount);
        assertEq(share1, share2);
    }

    function testBurnShares(uint _amount) public {
        _amount = bound(_amount, 1, 1e29);
        uint share1 = _mintPool(address(initCore), WBTC, _amount);
        _burnPool(address(initCore), WBTC, share1);
    }

    function testMintAfterAccruedDebt(uint _borrowAmount, uint _mintAmount) public {
        _mintAmount = bound(_mintAmount, 1, 1e29);
        _borrowAmount = bound(_borrowAmount, 1, _mintAmount);
        uint interestRate = 1e18; // 100% interest rate
        _setPoolInterestRate(WBTC, interestRate);

        // before accrued
        uint share1 = _mintPool(address(initCore), WBTC, _mintAmount);
        _borrow(WBTC, _borrowAmount); // 1 WBTC

        // after accrued
        vm.warp(block.timestamp + 1 seconds); // Debt should be doubled
        uint expectedShare2 = lendingPools[WBTC].toSharesCurrent(_mintAmount); // accrued debt
        uint share2 = _mintPool(address(initCore), WBTC, _mintAmount);

        assertEq(share2, expectedShare2);
        assertLt(share2, share1);
    }

    function testBorrowAfterAccruedDebt(uint _borrowAmount, uint _mintAmount) public {
        _mintAmount = bound(_mintAmount, 4, 1e29);
        _borrowAmount = bound(_borrowAmount, 2, _mintAmount / 2);
        uint interestRate = 1e18; // 100% interest rate
        _setPoolInterestRate(WBTC, interestRate);

        // before accrued
        _mintPool(address(initCore), WBTC, _mintAmount);
        uint debtShare1 = _borrow(WBTC, _borrowAmount); // 1 WBTC

        // after accrued
        vm.warp(block.timestamp + 1 seconds); // Debt should be doubled
        lendingPools[WBTC].accrueInterest();

        uint debtShare2 = _borrow(WBTC, _borrowAmount); // 1 WBTC

        assertLt(debtShare2, debtShare1);
    }

    function testBurnSharesAfterAccruedDebt(uint _mintAmount) public {
        _mintAmount = bound(_mintAmount, 1e8, 1e29);
        uint share1 = _mintPool(address(initCore), WBTC, 1e29);
        _borrow(WBTC, 1e8);

        // before accrued
        uint receiveAmt1 = _burnPool(address(initCore), WBTC, share1 / 10);
        // after accrued
        vm.warp(block.timestamp + 1 seconds); // Debt should be doubled
        lendingPools[WBTC].accrueInterest();

        uint receiveAmt2 = _burnPool(address(initCore), WBTC, share1 / 10);
        assertGt(receiveAmt2, receiveAmt1);
    }

    function testRepayAfterAccuredDebt(uint _repayShares) public {
        _mintPool(address(initCore), WBTC, 1e29);
        uint debtShares = _borrow(WBTC, 1e28);
        _repayShares = bound(_repayShares, 1, debtShares / 3);
        uint amountBefore = _repayPool(WBTC, _repayShares);

        // after accrued
        vm.warp(block.timestamp + 1 seconds);
        uint amountAfter = _repayPool(WBTC, _repayShares);
        assertGt(amountAfter, amountBefore);

        // logs
        console2.log('Amount Before', amountBefore);
        console2.log('Amount After', amountAfter);
    }

    function testAccrueDebtNoBorrowRate(uint _borrowAmount) public {
        // set interest rate to 0
        _newIRM(WBTC, 0);

        _mintPool(address(initCore), WBTC, 1e29);

        _borrowAmount = bound(_borrowAmount, 1, 1e29);
        _borrow(WBTC, _borrowAmount);

        uint totalDebtBefore = lendingPools[WBTC].totalDebt();
        uint cashBefore = lendingPools[WBTC].cash();
        uint totalDebtSharesBefore = lendingPools[WBTC].totalDebtShares();

        // accrued
        vm.warp(block.timestamp + 1 seconds); // Debt should be doubled
        lendingPools[WBTC].accrueInterest();

        uint totalDebtAfter = lendingPools[WBTC].totalDebt();
        uint cashAfter = lendingPools[WBTC].cash();
        uint totalDebtSharesAfter = lendingPools[WBTC].totalDebtShares();
        uint lastAccruedTime = lendingPools[WBTC].lastAccruedTime();

        assertEq(totalDebtAfter, totalDebtBefore);
        assertEq(cashAfter, cashBefore);
        assertEq(totalDebtSharesAfter, totalDebtSharesBefore);
        assertEq(lastAccruedTime, block.timestamp);
    }

    function testAccrueDebtNoBorrow(uint _mintAmount) public {
        _mintAmount = bound(_mintAmount, 1, 1e29);
        _mintPool(address(initCore), WBTC, _mintAmount);

        uint totalDebtBefore = lendingPools[WBTC].totalDebt();
        uint cashBefore = lendingPools[WBTC].cash();
        uint totalDebtSharesBefore = lendingPools[WBTC].totalDebtShares();

        // accrued
        vm.warp(block.timestamp + 1 seconds); // Debt should be doubled
        lendingPools[WBTC].accrueInterest();

        uint totalDebtAfter = lendingPools[WBTC].totalDebt();
        uint cashAfter = lendingPools[WBTC].cash();
        uint totalDebtSharesAfter = lendingPools[WBTC].totalDebtShares();
        uint lastAccruedTime = lendingPools[WBTC].lastAccruedTime();

        assertEq(totalDebtAfter, totalDebtBefore);
        assertEq(cashAfter, cashBefore);
        assertEq(totalDebtSharesAfter, totalDebtSharesBefore);
        assertEq(lastAccruedTime, block.timestamp);
    }

    function testAccrueDebtTwoTimes(uint _borrowAmount) public {
        _mintPool(address(initCore), WBTC, 1e29);

        _borrowAmount = bound(_borrowAmount, 1, 1e29);
        _borrow(WBTC, _borrowAmount);

        // accrued interests
        vm.warp(block.timestamp + 1 seconds); // Debt should be doubled
        lendingPools[WBTC].accrueInterest(); // accureInterest first time
        uint totalDebtBefore = lendingPools[WBTC].totalDebt();
        uint cashBefore = lendingPools[WBTC].cash();
        uint totalDebtSharesBefore = lendingPools[WBTC].totalDebtShares();
        lendingPools[WBTC].accrueInterest(); // accrueInterest second time (should be in the same block)

        uint totalDebtAfter = lendingPools[WBTC].totalDebt();
        uint cashAfter = lendingPools[WBTC].cash();
        uint totalDebtSharesAfter = lendingPools[WBTC].totalDebtShares();
        uint lastAccruedTime = lendingPools[WBTC].lastAccruedTime();

        assertEq(totalDebtAfter, totalDebtBefore);
        assertEq(cashAfter, cashBefore);
        assertEq(totalDebtSharesAfter, totalDebtSharesBefore);
        assertEq(lastAccruedTime, block.timestamp);
    }

    function testGetBorrowRate_e18() public {
        // no activity, cash = 0, debt = 0
        address poolWETH = address(lendingPools[WETH]);
        uint reserveFactor_e18 = ILendingPool(poolWETH).reserveFactor_e18();

        uint poolBorrRate_e18;
        uint poolSupplyRate_e18;
        uint irmBorrRate_e18;
        uint calculateSupplyRate_e18; // supply rate = borrow rate * (1 - reserve factor) * totalDebt / (cash + totalDebt)

        // initialize pool, cash = 0, debt = 0
        poolBorrRate_e18 = ILendingPool(poolWETH).getBorrowRate_e18();
        irmBorrRate_e18 = doubleSlopeIRM.getBorrowRate_e18(0, 0);
        poolSupplyRate_e18 = ILendingPool(poolWETH).getSupplyRate_e18();
        calculateSupplyRate_e18 = 0;
        assertEq(poolBorrRate_e18, irmBorrRate_e18);
        assertEq(poolSupplyRate_e18, calculateSupplyRate_e18);
        console2.log('------------- cash: 0e18, debt: 0e18 --------------');
        console2.log('      IRM Borrow Rate: ', irmBorrRate_e18);
        console2.log('WETH Pool Borrow Rate: ', poolBorrRate_e18);
        console2.log('Calculate Supply Rate: ', calculateSupplyRate_e18);
        console2.log('WETH Pool Supply Rate: ', poolSupplyRate_e18, '\n');

        // mint pool, cash = 10e18, debt = 0
        _mintPool(address(initCore), WETH, 10e18);
        poolBorrRate_e18 = ILendingPool(poolWETH).getBorrowRate_e18();
        irmBorrRate_e18 = doubleSlopeIRM.getBorrowRate_e18(10e18, 0);
        poolSupplyRate_e18 = ILendingPool(poolWETH).getSupplyRate_e18();
        calculateSupplyRate_e18 = (poolBorrRate_e18 * (1e18 - reserveFactor_e18) * 0e18) / (10e18 * 1e18);
        assertEq(poolBorrRate_e18, irmBorrRate_e18);
        assertEq(poolSupplyRate_e18, calculateSupplyRate_e18);
        console2.log('------------- cash: 10e18, debt: 0e18 --------------');
        console2.log('      IRM Borrow Rate: ', irmBorrRate_e18);
        console2.log('WETH Pool Borrow Rate: ', poolBorrRate_e18);
        console2.log('Calculate Supply Rate: ', calculateSupplyRate_e18);
        console2.log('WETH Pool Supply Rate: ', poolSupplyRate_e18, '\n');

        // borrow pool, cash = 8e18, debt = 2e18
        _borrow(WETH, 2e18);
        poolBorrRate_e18 = ILendingPool(poolWETH).getBorrowRate_e18();
        irmBorrRate_e18 = doubleSlopeIRM.getBorrowRate_e18(8e18, 2e18);
        poolSupplyRate_e18 = ILendingPool(poolWETH).getSupplyRate_e18();
        calculateSupplyRate_e18 = (poolBorrRate_e18 * (1e18 - reserveFactor_e18) * 2e18) / (10e18 * 1e18);
        assertEq(poolBorrRate_e18, irmBorrRate_e18);
        assertEq(poolSupplyRate_e18, calculateSupplyRate_e18);
        console2.log('------------- cash: 8e18, debt: 2e18 --------------');
        console2.log('      IRM Borrow Rate: ', irmBorrRate_e18);
        console2.log('WETH Pool Borrow Rate: ', poolBorrRate_e18);
        console2.log('Calculate Supply Rate: ', calculateSupplyRate_e18);
        console2.log('WETH Pool Supply Rate: ', poolSupplyRate_e18, '\n');
    }

    function _newIRM(address _token, uint _interestRate_e18) internal {
        startHoax(ADMIN);
        MockFixedRateIRM newIRM = new MockFixedRateIRM(_interestRate_e18);
        lendingPools[_token].setIrm(address(newIRM));
        assertEq(lendingPools[_token].irm(), address(newIRM));
        vm.stopPrank();
    }

    function _repayPool(address _token, uint _shares) internal returns (uint repayAmts) {
        startHoax(address(initCore));
        address lendingPoolAddress = address(lendingPools[_token]);
        repayAmts = ILendingPool(lendingPoolAddress).debtShareToAmtCurrent(_shares);
        uint repayAmtsStored = ILendingPool(lendingPoolAddress).debtShareToAmtStored(_shares);

        BorrowInfo memory borrowBefore;
        BorrowInfo memory borrowAfter;

        // gather info before
        borrowBefore.cash = ILendingPool(lendingPoolAddress).cash();
        borrowBefore.debtPrice = ILendingPool(lendingPoolAddress).debtShareToAmtCurrent(1e18);
        borrowBefore.totalAssets = ILendingPool(lendingPoolAddress).totalAssets();
        borrowBefore.totalDebt = ILendingPool(lendingPoolAddress).totalDebt();
        borrowBefore.totalDebtShares = ILendingPool(lendingPoolAddress).totalDebtShares();

        IERC20(WBTC).transfer(lendingPoolAddress, repayAmts);
        uint actualRepayAmts = ILendingPool(lendingPoolAddress).repay(_shares);

        // gather info After
        borrowAfter.cash = ILendingPool(lendingPoolAddress).cash();
        borrowAfter.debtPrice = ILendingPool(lendingPoolAddress).debtShareToAmtCurrent(1e18);
        borrowAfter.totalAssets = ILendingPool(lendingPoolAddress).totalAssets();
        borrowAfter.totalDebt = ILendingPool(lendingPoolAddress).totalDebt();
        borrowAfter.totalDebtShares = ILendingPool(lendingPoolAddress).totalDebtShares();
        borrowAfter.underlyingBalance = IERC20(_token).balanceOf(lendingPoolAddress);

        // check conditions
        assertEq(repayAmts, repayAmtsStored);
        assertEq(actualRepayAmts, repayAmts);
        assertGt(borrowAfter.cash, borrowBefore.cash);
        assertGe(borrowAfter.debtPrice, borrowBefore.debtPrice);
        assertEq(borrowAfter.totalDebt, borrowBefore.totalDebt - repayAmts);
        assertEq(borrowAfter.totalDebtShares, borrowBefore.totalDebtShares - _shares);
        assertEq(borrowAfter.totalAssets, borrowBefore.totalAssets);
        assertEq(borrowAfter.underlyingBalance, borrowAfter.cash);

        vm.stopPrank();
    }

    function _borrow(address _token, uint _amount) internal returns (uint shares) {
        address initCoreAddress = address(initCore);
        address lendingPoolAddress = address(lendingPools[_token]);
        startHoax(initCoreAddress);

        BorrowInfo memory borrowBefore;
        BorrowInfo memory borrowAfter;

        // gather info before
        borrowBefore.cash = ILendingPool(lendingPoolAddress).cash();
        borrowBefore.totalAssets = ILendingPool(lendingPoolAddress).totalAssets();
        borrowBefore.totalDebt = ILendingPool(lendingPoolAddress).totalDebt();
        borrowBefore.totalDebtShares = ILendingPool(lendingPoolAddress).totalDebtShares();

        // actions
        shares = lendingPools[_token].borrow(initCoreAddress, _amount);
        assertEq(shares, ILendingPool(lendingPoolAddress).debtAmtToShareStored(_amount));

        // gather info After
        borrowAfter.cash = ILendingPool(lendingPoolAddress).cash();
        borrowAfter.totalAssets = ILendingPool(lendingPoolAddress).totalAssets();
        borrowAfter.totalDebt = ILendingPool(lendingPoolAddress).totalDebt();
        borrowAfter.totalDebtShares = ILendingPool(lendingPoolAddress).totalDebtShares();
        borrowAfter.underlyingBalance = IERC20(_token).balanceOf(lendingPoolAddress);

        // check conditions
        assertLt(borrowAfter.cash, borrowBefore.cash);
        assertEq(borrowAfter.totalAssets, borrowBefore.totalAssets);
        assertGt(borrowAfter.totalDebt, borrowBefore.totalDebt);
        assertGt(borrowAfter.totalDebtShares, borrowBefore.totalDebtShares);
        assertGe(borrowAfter.underlyingBalance, borrowAfter.cash);
        vm.stopPrank();
    }

    function _mintPool(address _account, address _token, uint _amount) internal returns (uint shares) {
        startHoax(_account);
        address lendingPoolAddress = address(lendingPools[_token]);

        PoolInfo memory poolBefore;
        PoolInfo memory poolAfter;

        // gather info
        poolBefore.sharePrice = _sharePrice_e18(lendingPoolAddress);
        poolBefore.totalSupply = IERC20(lendingPoolAddress).totalSupply();
        poolBefore.totalAssets = ILendingPool(lendingPoolAddress).totalAssets();
        poolBefore.cash = ILendingPool(lendingPoolAddress).cash();
        uint accountShareBefore = IERC20(lendingPoolAddress).balanceOf(_account);

        // actions
        // wrap native or deal tokens
        if (_token == WMNT) {
            deal(_account, _amount);
            wrapCenter.wrapNative{value: _amount}(_account);
        } else {
            deal(_token, _account, _amount);
        }
        // transfer to lending pool WBTC
        IERC20(_token).transfer(lendingPoolAddress, _amount);
        // mintTo at initCore
        shares = initCore.mintTo(lendingPoolAddress, _account);

        // gather info
        poolAfter.sharePrice = _sharePrice_e18(lendingPoolAddress);
        poolAfter.totalSupply = IERC20(lendingPoolAddress).totalSupply();
        poolAfter.totalAssets = ILendingPool(lendingPoolAddress).totalAssets();
        poolAfter.cash = ILendingPool(lendingPoolAddress).cash();
        poolAfter.underlyingBalance = IERC20(_token).balanceOf(lendingPoolAddress);
        uint accountShareAfter = IERC20(lendingPoolAddress).balanceOf(_account);

        // check conditions
        assertGt(poolAfter.cash, poolBefore.cash);
        assertGe(poolAfter.sharePrice, poolBefore.sharePrice);
        assertGt(poolAfter.totalSupply, poolBefore.totalSupply);
        assertGt(poolAfter.totalAssets, poolBefore.totalAssets);
        assertEq(poolAfter.underlyingBalance, poolAfter.cash);
        assertEq(accountShareAfter, shares + accountShareBefore);
        assertGt(accountShareAfter, accountShareBefore);
        vm.stopPrank();
    }

    function _burnPool(address _account, address _token, uint _shares) internal returns (uint receivedAmount) {
        startHoax(_account);
        address lendingPoolAddress = address(lendingPools[_token]);

        PoolInfo memory poolBefore;
        PoolInfo memory poolAfter;

        // gather Info
        poolBefore.sharePrice = _sharePrice_e18(lendingPoolAddress);
        poolBefore.totalSupply = IERC20(lendingPoolAddress).totalSupply();
        poolBefore.totalAssets = ILendingPool(lendingPoolAddress).totalAssets();
        poolBefore.cash = ILendingPool(lendingPoolAddress).cash();
        uint underlyingBalanceBefore = IERC20(_token).balanceOf(_account);

        // transfer to lending pool WBTC
        IERC20(lendingPoolAddress).transfer(lendingPoolAddress, _shares);
        receivedAmount = lendingPools[_token].burn(_account);

        // gather info
        poolAfter.sharePrice = _sharePrice_e18(lendingPoolAddress);
        poolAfter.totalSupply = IERC20(lendingPoolAddress).totalSupply();
        poolAfter.totalAssets = ILendingPool(lendingPoolAddress).totalAssets();
        poolAfter.cash = ILendingPool(lendingPoolAddress).cash();
        poolAfter.underlyingBalance = IERC20(_token).balanceOf(lendingPoolAddress);
        uint underlyingBalanceAfter = IERC20(_token).balanceOf(_account);

        // check conditions
        assertLt(poolAfter.cash, poolBefore.cash);
        console2.log(poolAfter.cash, poolBefore.cash);
        console2.log(receivedAmount);
        assertGe(poolAfter.sharePrice, poolBefore.sharePrice);
        assertLt(poolAfter.totalSupply, poolBefore.totalSupply);
        assertLt(poolAfter.totalAssets, poolBefore.totalAssets);
        assertEq(poolAfter.cash, poolAfter.underlyingBalance);
        assertGt(underlyingBalanceAfter, underlyingBalanceBefore);
        vm.stopPrank();
    }

    function _setPoolInterestRate(address _token, uint _interestRateE18) internal {
        startHoax(ADMIN);
        MockFixedRateIRM newfixedRateIRM = new MockFixedRateIRM(_interestRateE18);
        lendingPools[_token].setIrm(address(newfixedRateIRM));
        vm.stopPrank();
    }

    function _sharePrice_e18(address pool) internal view returns (uint sharePrice) {
        uint totalAssets = ILendingPool(pool).totalAssets();
        uint totalSupply = IERC20(pool).totalSupply();
        totalAssets++;
        totalSupply += 1e8;
        sharePrice = (totalAssets * 1e18) / totalSupply;
    }

    function _wrapRebase(
        address _account,
        address _tokenIn,
        address _tokenOut,
        uint _amount,
        address _to,
        address _rebaseWrapHelperAddress
    ) internal {
        startHoax(_account);
        bytes[] memory calls = new bytes[](2);
        // 1. transfer token to lending pool
        calls[0] = abi.encodeWithSelector(initCore.transferToken.selector, _tokenIn, _rebaseWrapHelperAddress, _amount);
        // 2. wrap/unwrap token via wrap center
        bytes memory _wrapData =
            abi.encodeWithSelector(wrapCenter.wrapRebase.selector, _rebaseWrapHelperAddress, _tokenIn, _tokenOut, _to);

        calls[1] = abi.encodeWithSelector(initCore.callback.selector, address(wrapCenter), 0, _wrapData);
        initCore.multicall(calls);
        vm.stopPrank();
    }

    function _approveToken(address _account, address _token, uint _amount) internal {
        startHoax(_account);
        IERC20(_token).approve(address(initCore), _amount);
        vm.stopPrank();
    }
}
