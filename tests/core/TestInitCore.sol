// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '../helper/DeployAll.sol';
import '../../contracts/common/library/UncheckedIncrement.sol';

import {ILendingPool} from '../../contracts/interfaces/lending_pool/ILendingPool.sol';
import {PosManager} from '../../contracts/core/PosManager.sol';
import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin-contracts/token/ERC721/IERC721.sol';
import {IWNative} from '../../contracts/interfaces/common/IWNative.sol';
import {PoolConfig} from '../../contracts/interfaces/core/IConfig.sol';
import {MockFixedRateIRM} from '../../contracts/mock/MockFixedRateIRM.sol';

contract TestInitCore is DeployAll {
    using UncheckedIncrement for uint;

    address constant WHALE = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    struct CollateralInfo {
        address[] pools;
        uint[] amts;
        address[] wLps;
        uint[][] ids;
        uint[][] wLpAmts;
    }

    struct BorrowInfo {
        address[] pools;
        uint[] debtShares;
    }

    struct PositionInfo {
        uint amount;
        uint borrowCredit;
        uint health;
        uint debtShares;
        uint modeDebtShares;
        uint totalInterest;
        uint lastDebtAmt;
    }

    function testInitCoreSetter() public {
        vm.startPrank(ADMIN);
        initCore.setConfig(BEEF);
        assertEq(initCore.config(), BEEF);
        initCore.setOracle(BEEF);
        assertEq(initCore.oracle(), BEEF);
        initCore.setLiqIncentiveCalculator(BEEF);
        assertEq(initCore.liqIncentiveCalculator(), BEEF);
        initCore.setRiskManager(BEEF);
        assertEq(initCore.riskManager(), BEEF);
        vm.stopPrank();
    }

    function testMintExcessSupplyCapRevert() public {
        address poolAddress = address(lendingPools[WETH]);
        // config
        PoolConfig memory poolConfig = PoolConfig({
            supplyCap: 1e18,
            borrowCap: type(uint128).max,
            canMint: true,
            canBurn: true,
            canBorrow: true,
            canRepay: true,
            canFlash: true
        });
        _setPoolConfig(poolAddress, poolConfig);

        // mint pool
        // experctRevert SUPPLY_CAP_REACHED(#406)
        deal(WETH, ALICE, 2e18);
        _mintPool(ALICE, poolAddress, 2e18, bytes('#406'));
    }

    function testCreatePos() public {
        // create positions
        uint[] memory posIds = new uint[](5);
        for (uint i; i < posIds.length; ++i) {
            posIds[i] = _createPos(ALICE, BOB, 1);
        }

        vm.startPrank(ALICE);
        // set viewer an already viewer
        // expect revert ALREADY_SET (#106)
        vm.expectRevert(bytes('#106'));
        positionManager.setPosViewer(posIds[3], BOB);

        // set new viewer
        positionManager.setPosViewer(posIds[3], ALICE);
        positionManager.setPosViewer(posIds[4], ALICE);

        // check results
        console2.log('Viewer: ', BOB);
        for (uint i; i < positionManager.getViewerPosIdsLength(BOB); ++i) {
            uint posIdAt = positionManager.getViewerPosIdsAt(BOB, i);
            assertEq(posIdAt, posIds[i]);
            console2.log('Viewer PosId at Index', i, posIdAt);
            console2.log('PosId At Index', i, posIds[i]);
        }
        console2.log('Viewer: ', ALICE);
        for (uint i; i < positionManager.getViewerPosIdsLength(ALICE); ++i) {
            uint posIdAt = positionManager.getViewerPosIdsAt(ALICE, i);
            assertEq(posIdAt, posIds[i + 3]);
            console2.log('Viewer PosId at Index', i, posIdAt);
            console2.log('PosId At Index', i + 3, posIds[i + 3]);
        }
        vm.stopPrank();
    }

    function testTransferPosition() public {
        uint posId = _createPos(ALICE, ALICE, 2);
        _transferPosition(ALICE, BOB, posId);
    }

    function testCollateralPosition(uint _amount) public {
        _amount = bound(_amount, 1, 1e29);

        // create position
        uint posId = _createPos(ALICE, ALICE, 2);

        // collateralize
        deal(WETH, ALICE, _amount);
        _collateralizePosition(ALICE, posId, address(lendingPools[WETH]), _amount, bytes(''));
    }

    function testCollateralPositionWithUnsupportedTokenRevert(uint _amount) public {
        _amount = bound(_amount, 1, 1e29);

        // create position
        uint posId = _createPos(ALICE, ALICE, 2);

        // collateralize
        // expectRevert  INVALID_MODE(#500)
        deal(USDT, ALICE, _amount);
        _collateralizePosition(ALICE, posId, address(lendingPools[USDT]), _amount, bytes('#500'));
    }

    function testDecollateralizePosition(uint _amount) public {
        _amount = bound(_amount, 2, 1e29);
        address poolWETH = address(lendingPools[WETH]);

        // create position
        uint posId = _createPos(ALICE, ALICE, 2);

        // collateralize and decollateralize position
        deal(WETH, ALICE, _amount);
        _collateralizePosition(ALICE, posId, poolWETH, _amount, bytes(''));

        (CollateralInfo memory collateralInfo,) = _getCollateralBorrowInfo(posId);
        uint wethIndex = _getPoolIndex(collateralInfo.pools, poolWETH);

        (, bool isInCollateralPoolsAfter) =
            _decollateralizePosition(ALICE, posId, poolWETH, collateralInfo.amts[wethIndex] - 1, bytes(''));

        // check conditions
        assertEq(isInCollateralPoolsAfter, true);
    }

    function testDecollateralizePositionToEmpty(uint _amount) public {
        _amount = bound(_amount, 1, 1e29);
        address poolWETH = address(lendingPools[WETH]);

        // create position & collateralize
        deal(WETH, ALICE, _amount);
        uint posId = _createPos(ALICE, ALICE, 2);
        _collateralizePosition(ALICE, posId, poolWETH, _amount, bytes(''));
        (CollateralInfo memory collateralInfo,) = _getCollateralBorrowInfo(posId);
        uint wethIndex = _getPoolIndex(collateralInfo.pools, poolWETH);
        (uint collAmtsAfter, bool isInCollateralPoolsAfter) =
            _decollateralizePosition(ALICE, posId, poolWETH, collateralInfo.amts[wethIndex], bytes(''));

        // check conditions
        assertEq(collAmtsAfter, 0);
        assertEq(isInCollateralPoolsAfter, false);
    }

    function testCollateralPositionWithNewPool(uint _amount) public {
        _amount = bound(_amount, 1, 200);
        address poolWETH = address(lendingPools[WETH]);
        address poolWBTC = address(lendingPools[WBTC]);

        // create position & collateralize
        deal(WETH, ALICE, _amount);
        deal(WBTC, ALICE, _amount);
        uint posId = _createPos(ALICE, ALICE, 2);
        _collateralizePosition(ALICE, posId, poolWETH, _amount, bytes(''));
        (CollateralInfo memory collateralInfoBefore,) = _getCollateralBorrowInfo(posId);
        _collateralizePosition(ALICE, posId, poolWBTC, _amount, bytes(''));
        (CollateralInfo memory collateralInfoAfter,) = _getCollateralBorrowInfo(posId);

        // check conditions
        assertEq(collateralInfoAfter.pools.length, collateralInfoBefore.pools.length + 1);
    }

    function testBorrowPosition(uint _amount) public {
        uint collAmts;
        uint borrAmts;

        {
            uint collUSD = 100_000;
            uint borrUSDMax = 50_000;
            collAmts = _priceToTokenAmt(WBTC, collUSD);
            borrAmts = _priceToTokenAmt(WETH, borrUSDMax);
        }
        _amount = bound(_amount, 1, borrAmts);
        address poolWETH = address(lendingPools[WETH]);
        address poolWBTC = address(lendingPools[WBTC]);

        // whale funds the pool
        _fundPool(poolWETH, 1e29);

        // create position
        uint posId = _createPos(ALICE, ALICE, 2);

        // collateralized
        deal(WBTC, ALICE, collAmts);
        _collateralizePosition(ALICE, posId, poolWBTC, collAmts, bytes(''));

        // borrow
        (, BorrowInfo memory borrowInfoBefore) = _getCollateralBorrowInfo(posId);
        _borrow(ALICE, posId, poolWETH, _amount, bytes(''));
        (, BorrowInfo memory borrowInfoAfter) = _getCollateralBorrowInfo(posId);

        // check conditions
        assertEq(borrowInfoAfter.pools.length, borrowInfoBefore.pools.length + 1);
        assertEq(_isListContain(borrowInfoAfter.pools, poolWETH), true);

        // check mode debt
        // accrue interest
        vm.warp(block.timestamp + 1 seconds);
        uint modeDebtCurrent = riskManager.getModeDebtAmtCurrent(2, poolWETH);
        uint modeDebtStored = riskManager.getModeDebtAmtStored(2, poolWETH);
        uint poolTotalDebt = ILendingPool(poolWETH).totalDebt();
        assertEq(modeDebtStored, modeDebtCurrent);
        assertEq(modeDebtStored, poolTotalDebt);
    }

    function testBorrowPositionSameToken(uint _amount) public {
        uint collAmts;
        uint borrAmts;

        {
            uint collUSD = 100_000;
            uint borrUSDMax = 50_000;
            collAmts = _priceToTokenAmt(WBTC, collUSD);
            borrAmts = _priceToTokenAmt(WETH, borrUSDMax);
        }

        _amount = bound(_amount, 1, borrAmts / 3);
        address poolWETH = address(lendingPools[WETH]);
        address poolWBTC = address(lendingPools[WBTC]);
        _setFixedRateIRM(poolWETH, 1e18); // 100% per sec

        // whale funds the pool
        _fundPool(poolWETH, 1e29);

        // create position
        uint posId = _createPos(ALICE, ALICE, 2);

        // collateralized
        deal(WBTC, ALICE, collAmts);
        _collateralizePosition(ALICE, posId, poolWBTC, collAmts, bytes(''));

        // borrow
        _borrow(ALICE, posId, poolWETH, _amount, bytes(''));
        (, BorrowInfo memory borrowInfoBefore) = _getCollateralBorrowInfo(posId);
        _borrow(ALICE, posId, poolWETH, _amount, bytes(''));
        (, BorrowInfo memory borrowInfoAfter) = _getCollateralBorrowInfo(posId);

        // check conditions
        assertEq(borrowInfoAfter.pools.length, borrowInfoBefore.pools.length);

        // check mode debt
        // accrue interest
        vm.warp(block.timestamp + 1 seconds);
        uint modeDebtCurrent = riskManager.getModeDebtAmtCurrent(2, poolWETH);
        uint modeDebtStored = riskManager.getModeDebtAmtStored(2, poolWETH);
        uint poolTotalDebt = ILendingPool(poolWETH).totalDebt();
        assertEq(modeDebtStored, modeDebtCurrent);
        assertEq(modeDebtStored, poolTotalDebt);

        (uint totalInterestBefore,) = positionManager.getPosBorrExtraInfo(posId, poolWETH);
        _borrow(ALICE, posId, poolWETH, _amount, bytes(''));
        (uint totalInterestAfter,) = positionManager.getPosBorrExtraInfo(posId, poolWETH);
        assertEq(totalInterestAfter - totalInterestBefore, 2 * _amount);
    }

    function testBorrowExcessModeDebtCeilingRevert() public {
        address poolWETH = address(lendingPools[WETH]);
        address poolWBTC = address(lendingPools[WBTC]);

        // whale funds the pool
        _fundPool(poolWETH, 1e29);

        uint16 mode = 2;
        uint debtCeiling = riskManager.getModeDebtCeilingAmt(mode, poolWETH);

        // create position
        uint posId = _createPos(ALICE, ALICE, mode);

        // collateralized
        deal(WBTC, ALICE, 2e8);
        _collateralizePosition(ALICE, posId, poolWBTC, 2e8, bytes(''));

        // borrow
        // expectRevert DEBT_CEILING_EXCEEDED (#800)
        _borrow(ALICE, posId, poolWETH, debtCeiling + 1, bytes('#800'));
    }

    function testBorrowExcessPoolBorrowCapRevert() public {
        address poolWETH = address(lendingPools[WETH]);
        address poolWBTC = address(lendingPools[WBTC]);
        uint16 mode = 2;

        // whale funds the pool
        _fundPool(poolWETH, 1e29);

        uint collAmts;
        uint128 borrAmts;

        {
            uint collUSD = 100_000;
            uint borrUSDMax = 50_000;
            collAmts = _priceToTokenAmt(WBTC, collUSD);
            borrAmts = uint128(_priceToTokenAmt(WETH, borrUSDMax));
        }

        // set pool config
        PoolConfig memory poolConfig = PoolConfig({
            supplyCap: type(uint128).max,
            borrowCap: borrAmts - 1,
            canMint: true,
            canBurn: true,
            canBorrow: true,
            canRepay: true,
            canFlash: true
        });
        _setPoolConfig(poolWETH, poolConfig);

        // create position
        uint posId = _createPos(ALICE, ALICE, mode);

        // collateralized
        deal(WBTC, ALICE, collAmts);
        _collateralizePosition(ALICE, posId, poolWBTC, collAmts, bytes(''));

        // borrow
        // expectRevert BORROW_CAP_REACHED(#407)
        _borrow(ALICE, posId, poolWETH, borrAmts, bytes('#407'));
    }

    function testRepayPosition(uint _repayShares) public {
        address poolWETH = address(lendingPools[WETH]);
        address poolWBTC = address(lendingPools[WBTC]);
        _setFixedRateIRM(poolWETH, 1e18); // 100% per sec

        uint collAmts;
        uint borrAmts;

        {
            uint collUSD = 100_000;
            uint borrUSDMax = 50_000;
            collAmts = _priceToTokenAmt(WBTC, collUSD);
            borrAmts = _priceToTokenAmt(WETH, borrUSDMax);
        }

        // whale funds the pool
        _fundPool(poolWETH, borrAmts);

        // create position
        uint posId = _createPos(ALICE, ALICE, 2);

        // collateralized
        deal(WBTC, ALICE, collAmts);
        _collateralizePosition(ALICE, posId, poolWBTC, collAmts, bytes(''));

        // borrow
        uint borrowShares = _borrow(ALICE, posId, poolWETH, borrAmts, bytes(''));
        // NOTE repay too low will not change the health of the position
        _repayShares = bound(_repayShares, 10, borrowShares / 2);

        vm.warp(block.timestamp + 1 seconds);
        (uint totalInterestBefore,) = positionManager.getPosBorrExtraInfo(posId, poolWETH);

        // Repay
        // repay partial, pool should be still in the borrow list
        // uint payAmts = lendingPools[WETH].debtShareToAmtCurrent(_repayShares);
        bool isInBorrowPoolsAfter = _repay(ALICE, posId, address(lendingPools[WETH]), _repayShares);
        assertEq(isInBorrowPoolsAfter, true);

        // check interest
        uint modeDebtCurrent = riskManager.getModeDebtAmtCurrent(2, poolWETH);
        uint modeDebtStored = riskManager.getModeDebtAmtStored(2, poolWETH);
        uint poolTotalDebt = ILendingPool(poolWETH).totalDebt();
        assertEq(modeDebtStored, modeDebtCurrent);
        assertEq(modeDebtStored, poolTotalDebt);

        (uint totalInterestAfter,) = positionManager.getPosBorrExtraInfo(posId, poolWETH);
        console.log('TotalInterest Before: ', totalInterestBefore);
        console.log('TotalInterest After: ', totalInterestAfter);
        // interest = 1 second * 100% = 100%
        assertEq(totalInterestAfter - totalInterestBefore, borrAmts);
    }

    function testRepayPositionAllDebtShares() public {
        address poolWETH = address(lendingPools[WETH]);
        address poolWBTC = address(lendingPools[WBTC]);

        // whale funds the pool
        _fundPool(poolWETH, 1e29);

        // create position
        uint posId = _createPos(ALICE, ALICE, 2);

        uint collAmts;
        uint borrAmts;

        {
            uint collUSD = 100_000;
            uint borrUSDMax = 50_000;
            collAmts = _priceToTokenAmt(WBTC, collUSD);
            borrAmts = _priceToTokenAmt(WETH, borrUSDMax);
        }
        // collateralized
        deal(WBTC, ALICE, collAmts);

        // deal(WETH, ALICE, 1e8);
        _collateralizePosition(ALICE, posId, poolWBTC, collAmts, bytes(''));

        // borrow
        uint borrowShares = _borrow(ALICE, posId, poolWETH, borrAmts, bytes(''));

        // Repay
        // repay all, pool should be removed from the borrow list
        bool isInBorrowPoolsAfter = _repay(ALICE, posId, address(lendingPools[WETH]), borrowShares);
        assertEq(isInBorrowPoolsAfter, false);
    }

    function testMultiCollateralizeBorrowPosition() public {
        address[4] memory tokens = [WETH, WBTC, USDT, WMNT];
        uint[] memory collAmts = new uint[](4);
        uint[] memory borrAmts = new uint[](4);
        for (uint i; i < tokens.length; i++) {
            uint collAmt;
            uint borrAmt;
            {
                uint collUSD = 100_000;
                uint borrUSDMax = 50_000;
                collAmt = _priceToTokenAmt(tokens[i], collUSD);
                borrAmt = _priceToTokenAmt(tokens[i], borrUSDMax);
            }
            collAmts[i] = collAmt;
            borrAmts[i] = borrAmt;
        }

        // create a position
        uint posId = _createPos(ALICE, ALICE, 1);

        // collateralize and borrow
        for (uint i; i < tokens.length; i = i.uinc()) {
            address lendingpool = address(lendingPools[tokens[i]]);
            deal(tokens[i], ALICE, collAmts[i]); // 1 WETH
            _collateralizePosition(ALICE, posId, lendingpool, collAmts[i], bytes('')); // collateralize
            _borrow(ALICE, posId, lendingpool, borrAmts[i], bytes('')); // borrow
        }

        uint positionHealth = initCore.getPosHealthCurrent_e18(posId);
        (CollateralInfo memory collInfo, BorrowInfo memory borrowInfo) = _getCollateralBorrowInfo(posId);

        // checking
        assertGt(positionHealth, 1);
        for (uint i; i < tokens.length; i = i.uinc()) {
            address lendingPool = address(lendingPools[tokens[i]]);
            assertEq(ILendingPool(lendingPool).toAmt(collInfo.amts[i]), collAmts[i]);
            assertEq(borrowInfo.debtShares[i], borrAmts[i]);
        }
    }

    function testTwoUsersMultiCollateralizeBorrowPosition() public {
        address[4] memory tokens = [WETH, WBTC, USDT, WMNT];
        uint[] memory collAmts = new uint[](4);
        uint[] memory borrAmts = new uint[](4);
        for (uint i; i < tokens.length; i++) {
            uint collAmt;
            uint borrAmt;
            {
                uint collUSD = 100_000;
                uint borrUSDMax = 50_000;
                collAmt = _priceToTokenAmt(tokens[i], collUSD);
                borrAmt = _priceToTokenAmt(tokens[i], borrUSDMax);
            }
            collAmts[i] = collAmt;
            borrAmts[i] = borrAmt;
        }

        // create a position
        uint posId1 = _createPos(ALICE, ALICE, 1);
        uint posId2 = _createPos(BOB, BOB, 1);

        // collateralize and borrow
        for (uint i; i < tokens.length; i = i.uinc()) {
            address lendingpool = address(lendingPools[tokens[i]]);
            deal(tokens[i], ALICE, collAmts[i]); // 1 WETH
            deal(tokens[i], BOB, collAmts[i]); // 1 WETH
            _collateralizePosition(ALICE, posId1, lendingpool, collAmts[i], bytes('')); // collateralize
            _borrow(ALICE, posId1, lendingpool, borrAmts[i], bytes('')); // borrow
            _collateralizePosition(BOB, posId2, lendingpool, collAmts[i], bytes('')); // collateralize
            _borrow(BOB, posId2, lendingpool, borrAmts[i], bytes('')); // borrow
        }

        uint pos1Health = initCore.getPosHealthCurrent_e18(posId1);
        uint pos2Health = initCore.getPosHealthCurrent_e18(posId2);

        (CollateralInfo memory pos1CollInfo, BorrowInfo memory pos1BorrowInfo) = _getCollateralBorrowInfo(posId1);
        (CollateralInfo memory pos2CollInfo, BorrowInfo memory pos2BorrowInfo) = _getCollateralBorrowInfo(posId2);

        // checking
        assertEq(initCore.getCollateralCreditCurrent_e36(posId1), initCore.getCollateralCreditCurrent_e36(posId2));
        assertEq(initCore.getBorrowCreditCurrent_e36(posId1), initCore.getBorrowCreditCurrent_e36(posId2));
        assertGt(pos1Health, 1);
        assertGt(pos2Health, 1);
        for (uint i; i < tokens.length - 1; i = i.uinc()) {
            address lendingPool = address(lendingPools[tokens[i]]);
            assertEq(ILendingPool(lendingPool).toAmt(pos1CollInfo.amts[i]), collAmts[i]);
            assertEq(ILendingPool(lendingPool).toAmt(pos2CollInfo.amts[i]), collAmts[i]);
            assertEq(pos1BorrowInfo.debtShares[i], borrAmts[i]);
            assertEq(pos2BorrowInfo.debtShares[i], borrAmts[i]);
        }
    }

    function testDecollateralizeUnhealthyPositionRevert() public {
        address poolWETH = address(lendingPools[WETH]);
        address poolWBTC = address(lendingPools[WBTC]);

        // whale funds the pool
        _fundPool(poolWETH, 1e29);

        // create position
        uint posId = _createPos(ALICE, ALICE, 2);

        uint collAmt;
        uint borrAmt;

        {
            uint collUSD = 100_000;
            uint borrUSDMax = 50_000;
            collAmt = _priceToTokenAmt(WBTC, collUSD);
            borrAmt = _priceToTokenAmt(WETH, borrUSDMax);
        }

        // collateralize and decollateralize position
        deal(WBTC, ALICE, collAmt);
        (uint actualCollAmt,,) = _collateralizePosition(ALICE, posId, poolWBTC, collAmt, bytes(''));
        _borrow(ALICE, posId, poolWETH, borrAmt, bytes(''));

        // expect revert because of unhealthy position
        _decollateralizePosition(ALICE, posId, poolWBTC, actualCollAmt, bytes('#300'));
    }

    function testBorrowUnhealthyPositionRevert() public {
        address poolWETH = address(lendingPools[WETH]);
        address poolWBTC = address(lendingPools[WBTC]);

        // whale funds the pool
        _fundPool(poolWETH, 1e29);

        // create position
        uint posId = _createPos(ALICE, ALICE, 2);

        uint collAmt;
        uint borrAmt;

        {
            uint collUSD = 100_000;
            uint borrUSDMax = 110_000;
            collAmt = _priceToTokenAmt(WBTC, collUSD);
            borrAmt = _priceToTokenAmt(WETH, borrUSDMax);
        }

        // collateralize and decollateralize position
        deal(WBTC, ALICE, collAmt);
        _collateralizePosition(ALICE, posId, poolWBTC, collAmt, bytes(''));
        _borrow(ALICE, posId, poolWETH, borrAmt, bytes('#300'));
    }

    function testLiquidatePosition() public {
        address poolUSDT = address(lendingPools[USDT]);
        address poolWBTC = address(lendingPools[WBTC]);
        _setFixedRateIRM(poolWBTC, 0.1e18); // 1% per sec
        uint collAmt;
        uint borrAmt;

        {
            uint collUSD = 100_000;
            uint borrUSDMax = 80_000;
            collAmt = _priceToTokenAmt(USDT, collUSD);
            borrAmt = _priceToTokenAmt(WBTC, borrUSDMax);
        }

        deal(USDT, ALICE, collAmt);
        deal(WBTC, BOB, borrAmt);

        // provides liquidity for borrow
        _fundPool(poolWBTC, borrAmt);

        uint posId = _createPos(ALICE, ALICE, 1);

        _collateralizePosition(ALICE, posId, poolUSDT, collAmt, bytes(''));

        // borrow & accrue interest
        uint debtShares = _borrow(ALICE, posId, poolWBTC, borrAmt, bytes(''));
        vm.warp(block.timestamp + 1 seconds);
        ILendingPool(poolWBTC).accrueInterest();

        _liquidate(BOB, posId, debtShares / 3, poolWBTC, poolUSDT, false, bytes(''));
    }

    function testLiquidateAllDebtPosition() public {
        address poolUSDT = address(lendingPools[USDT]);
        address poolWBTC = address(lendingPools[WBTC]);
        _setTargetHealthAfterLiquidation_e18(1, type(uint64).max); // by pass max health after liquidate capped
        _setFixedRateIRM(poolWBTC, 0.1e18); // 10% per sec

        uint collAmt;
        uint borrAmt;

        {
            uint collUSD = 100_000;
            uint borrUSDMax = 80_000;
            collAmt = _priceToTokenAmt(USDT, collUSD);
            borrAmt = _priceToTokenAmt(WBTC, borrUSDMax);
        }

        address liquidator = BOB;
        deal(USDT, ALICE, collAmt);
        deal(WBTC, liquidator, borrAmt * 2);

        // provides liquidity for borrow
        _fundPool(poolWBTC, borrAmt);

        // create position and collateralize
        uint posId = _createPos(ALICE, ALICE, 1);
        _collateralizePosition(ALICE, posId, poolUSDT, collAmt, bytes(''));

        // borrow
        _borrow(ALICE, posId, poolWBTC, borrAmt, bytes(''));

        // fast forward time and accrue interest
        vm.warp(block.timestamp + 1 seconds);
        ILendingPool(poolWBTC).accrueInterest();

        uint healthBefore = initCore.getPosHealthCurrent_e18(posId);
        uint debtShares = positionManager.getPosDebtShares(posId, poolWBTC);

        // liquidate all debtShares
        _liquidate(liquidator, posId, debtShares, poolWBTC, poolUSDT, false, bytes(''));

        // gather info
        uint healthAfter = initCore.getPosHealthCurrent_e18(posId);
        uint maxHealth = config.getMaxHealthAfterLiq_e18(1);
        (, BorrowInfo memory borrowInfoAfter) = _getCollateralBorrowInfo(posId);

        // check conditions
        assertEq(_isListContain(borrowInfoAfter.pools, poolWBTC), false);

        // logs
        console2.log('Health Before', healthBefore);
        console2.log('Health After', healthAfter);
        console2.log('MaxHealth', maxHealth);
    }

    function testLiquidateHealthyPositionRevert() public {
        address poolWBTC = address(lendingPools[WBTC]);
        address poolUSDT = address(lendingPools[USDT]);

        uint collAmt;
        uint borrAmt;

        {
            uint collUSD = 100_000;
            uint borrUSDMax = 80_000;
            collAmt = _priceToTokenAmt(USDT, collUSD);
            borrAmt = _priceToTokenAmt(WBTC, borrUSDMax);
        }

        // whale provides liquidity for borrow
        _fundPool(poolWBTC, borrAmt);

        // create position
        uint posId = _createPos(ALICE, ALICE, 1);

        deal(USDT, ALICE, collAmt);
        _collateralizePosition(ALICE, posId, poolUSDT, collAmt, bytes(''));

        // borrow & accrue interest
        uint debtShares = _borrow(ALICE, posId, poolWBTC, borrAmt, bytes(''));

        // liqudiate healthy position
        // expect revert POSITION_HEALTHY(#303)
        _liquidate(BOB, posId, debtShares / 3, poolWBTC, poolUSDT, false, bytes('#303'));
    }

    function testLiquidateUnderwaterPositionPartial() public {
        address poolUSDT = address(lendingPools[USDT]);
        address poolWBTC = address(lendingPools[WBTC]);
        _setTargetHealthAfterLiquidation_e18(1, type(uint64).max); // by pass max health after liquidate capped
        _setFixedRateIRM(poolWBTC, 1e18); // 100% per sec
        uint collAmt;
        uint borrAmt;

        {
            uint collUSD = 100_000;
            uint borrUSDMax = 80_000;
            collAmt = _priceToTokenAmt(USDT, collUSD);
            borrAmt = _priceToTokenAmt(WBTC, borrUSDMax);
        }

        deal(USDT, ALICE, collAmt);

        // provides liquidity for borrow
        _fundPool(poolWBTC, borrAmt * 2);

        uint posId = _createPos(ALICE, ALICE, 1);
        _collateralizePosition(ALICE, posId, poolUSDT, collAmt, bytes(''));
        uint debtShares = _borrow(ALICE, posId, poolWBTC, borrAmt, bytes(''));

        // accrue interest
        vm.warp(block.timestamp + 1 seconds);
        ILendingPool(poolWBTC).accrueInterest();
        uint borrowAmts = ILendingPool(poolWBTC).debtShareToAmtCurrent(borrAmt);

        deal(WBTC, BOB, borrowAmts);
        _liquidate(BOB, posId, debtShares * 9 / 10, poolWBTC, poolUSDT, true, bytes(''));

        (CollateralInfo memory collateralInfoAfter, BorrowInfo memory borrowInfoAfter) = _getCollateralBorrowInfo(posId);

        // check conditions
        assertEq(_isListContain(collateralInfoAfter.pools, poolUSDT), false);
        assertEq(_isListContain(borrowInfoAfter.pools, poolWBTC), true);
    }

    function testLiquidateUnderwaterPositionProtocolRealizeBadDebt() public {
        address poolUSDT = address(lendingPools[USDT]);
        address poolWBTC = address(lendingPools[WBTC]);
        _setTargetHealthAfterLiquidation_e18(1, type(uint64).max); // by pass max health after liquidate capped
        _setFixedRateIRM(poolWBTC, 1e18); // 100% per sec
        uint collAmt;
        uint borrAmt;

        {
            uint collUSD = 100_000;
            uint borrUSDMax = 80_000;
            collAmt = _priceToTokenAmt(USDT, collUSD);
            borrAmt = _priceToTokenAmt(WBTC, borrUSDMax);
        }

        deal(USDT, ALICE, collAmt);

        // provides liquidity for borrow
        _fundPool(poolWBTC, borrAmt * 2);

        uint posId = _createPos(ALICE, ALICE, 1);
        _collateralizePosition(ALICE, posId, poolUSDT, collAmt, bytes(''));
        uint debtShares = _borrow(ALICE, posId, poolWBTC, borrAmt, bytes(''));

        // accrue interest
        vm.warp(block.timestamp + 1 seconds);
        ILendingPool(poolWBTC).accrueInterest();
        uint borrowAmts = ILendingPool(poolWBTC).debtShareToAmtCurrent(borrAmt);

        deal(WBTC, BOB, borrowAmts);
        _liquidate(BOB, posId, debtShares * 9 / 10, poolWBTC, poolUSDT, true, bytes(''));

        (CollateralInfo memory collateralInfoAfter, BorrowInfo memory borrowInfoAfter) = _getCollateralBorrowInfo(posId);

        // check conditions
        assertEq(_isListContain(collateralInfoAfter.pools, poolUSDT), false);
        assertEq(_isListContain(borrowInfoAfter.pools, poolWBTC), true);

        for (uint i; i < collateralInfoAfter.amts.length; ++i) {
            console.log(collateralInfoAfter.amts[i]);
        }
        for (uint i; i < borrowInfoAfter.debtShares.length; ++i) {
            console.log(borrowInfoAfter.debtShares[i]);
        }

        // protocol try closing under water position
        _liquidate(BOB, posId, borrowInfoAfter.debtShares[0], poolWBTC, poolUSDT, true, bytes(''));
    }

    function testLiquidatePositionInvalidRepayToken() public {
        address poolWBTC = address(lendingPools[WBTC]);
        address poolUSDT = address(lendingPools[USDT]);
        address poolWMNT = address(lendingPools[WMNT]);
        _setFixedRateIRM(poolWBTC, 0.01e18); // 1% per sec

        uint collAmt;
        uint borrAmt;

        {
            uint collUSD = 100_000;
            uint borrUSDMax = 80_000;
            collAmt = _priceToTokenAmt(USDT, collUSD);
            borrAmt = _priceToTokenAmt(WBTC, borrUSDMax);
        }

        // whale provides liquidity for borrow
        _fundPool(poolWBTC, borrAmt);

        // create position
        uint posId = _createPos(ALICE, ALICE, 1);

        deal(USDT, ALICE, collAmt);
        _collateralizePosition(ALICE, posId, poolUSDT, collAmt, bytes(''));

        // borrow & accrue interest
        uint debtShares = _borrow(ALICE, posId, poolWBTC, borrAmt, bytes(''));

        // accrue interest
        vm.warp(block.timestamp + 1 seconds);
        ILendingPool(poolWBTC).accrueInterest();

        // liquidate
        deal(WMNT, BOB, debtShares / 3);
        // expect revert panic cause by devided by 0
        _liquidate(BOB, posId, debtShares / 3, poolWMNT, poolUSDT, false, bytes('panic'));
    }

    function testLiquidatePositionInvalidOutputToken() public {
        address poolWBTC = address(lendingPools[WBTC]);
        address poolUSDT = address(lendingPools[USDT]);
        address poolWMNT = address(lendingPools[WMNT]);
        _setFixedRateIRM(poolWBTC, 0.1e18); // 10% per sec

        uint collAmt;
        uint borrAmt;

        {
            uint collUSD = 100_000;
            uint borrUSDMax = 80_000;
            collAmt = _priceToTokenAmt(USDT, collUSD);
            borrAmt = _priceToTokenAmt(WBTC, borrUSDMax);
        }

        // whale provides liquidity for borrow
        _fundPool(poolWBTC, borrAmt);
        _fundPool(poolWMNT, 1e30);

        // create position
        uint posId = _createPos(ALICE, ALICE, 1);

        deal(USDT, ALICE, collAmt);
        _collateralizePosition(ALICE, posId, poolUSDT, collAmt, bytes(''));

        // borrow & accrue interest
        uint debtShares = _borrow(ALICE, posId, poolWBTC, borrAmt, bytes(''));

        // accrue interest
        vm.warp(block.timestamp + 1 seconds);
        ILendingPool(poolWBTC).accrueInterest();

        // liqudiate
        uint liquidateAmts = ILendingPool(poolWBTC).debtShareToAmtCurrent(debtShares / 3);
        deal(WBTC, BOB, liquidateAmts);
        // (shares is zero and bypass removeCollateralTo)
        // expert revert INVALID_HEALTH_AFTER_LIQUIDATION
        _liquidate(BOB, posId, debtShares / 3, poolWBTC, poolWMNT, false, bytes('#304'));
    }

    function testChangeMode() public {
        address[3] memory tokens = [WBTC, WETH, WMNT];
        uint posId = _createPos(ALICE, ALICE, 1);
        for (uint i; i < tokens.length; i++) {
            deal(tokens[i], ALICE, 1e36);
            _collateralizePosition(ALICE, posId, address(lendingPools[tokens[i]]), 1e18, bytes(''));
        }

        (CollateralInfo memory collateralInfoBefore, BorrowInfo memory borrowInfoBefore) =
            _getCollateralBorrowInfo(posId);
        uint currentMode = _changeMode(ALICE, posId, 2, bytes(''));
        (CollateralInfo memory collateralInfoAfter, BorrowInfo memory borrowInfoAfter) = _getCollateralBorrowInfo(posId);

        //check
        require(collateralInfoAfter.pools.length == collateralInfoBefore.pools.length, 'Array Length Not Matched');
        require(collateralInfoAfter.wLps.length == collateralInfoBefore.wLps.length, 'Array Length Not Matched');
        require(borrowInfoAfter.pools.length == borrowInfoBefore.pools.length, 'Array Length Not Matched');

        for (uint i; i < collateralInfoAfter.pools.length; i = i.uinc()) {
            require(collateralInfoAfter.amts[i] == collateralInfoBefore.amts[i], 'Collateral Amounts Not Matched');
        }
        for (uint i; i < collateralInfoAfter.wLps.length; i = i.uinc()) {
            for (uint j; j < collateralInfoAfter.ids[i].length; j = j.uinc()) {
                require(collateralInfoAfter.ids[i][j] == collateralInfoBefore.ids[i][j], 'Collateral Ids Not Matched');
                require(
                    collateralInfoAfter.wLpAmts[i][j] == collateralInfoBefore.wLpAmts[i][j],
                    'Collateral Amounts Not Matched'
                );
            }
        }
        for (uint i; i < borrowInfoAfter.pools.length; i = i.uinc()) {
            require(borrowInfoAfter.debtShares[i] == borrowInfoBefore.debtShares[i], 'Debtshares  Not Matched');
        }

        assertEq(currentMode, 2);
    }

    function testChangeModeRevert() public {
        address[4] memory tokens = [WBTC, WETH, USDT, WMNT];
        uint pos = _createPos(ALICE, ALICE, 1);
        for (uint i; i < tokens.length; i++) {
            deal(tokens[i], ALICE, 1e36);
            _collateralizePosition(ALICE, pos, address(lendingPools[tokens[i]]), 1e18, bytes(''));
        }

        // expectRevert INVALID_MODE(#500)
        _changeMode(ALICE, pos, 2, bytes('#500'));
    }

    function testChangeModeBorrowCapRevert() public {
        address poolWETH = address(lendingPools[WETH]);
        address poolWBTC = address(lendingPools[WBTC]);

        _fundPool(poolWETH, 800e18);

        uint pos = _createPos(ALICE, ALICE, 1);

        deal(WBTC, ALICE, 200e8);
        _collateralizePosition(ALICE, pos, poolWBTC, 200e8, bytes(''));
        _borrow(ALICE, pos, poolWETH, 800e18, bytes(''));
        // expectRevert DEBT_CEILING_EXCEEDED(#800)
        _changeMode(ALICE, pos, 2, bytes('#800'));
    }

    function testChangeModeHealthRevert() public {
        address poolWETH = address(lendingPools[WETH]);
        address poolWBTC = address(lendingPools[WBTC]);

        // whale funds the pool
        _fundPool(poolWETH, 800e18);

        // create position
        uint pos = _createPos(ALICE, ALICE, 2);

        // collateralizes & borrow
        uint collUSD = 11_000;
        uint borrUSD = 9_200;
        uint collAmts = _priceToTokenAmt(WBTC, collUSD);
        uint borrAmts = _priceToTokenAmt(WETH, borrUSD);
        // console2.log('HealthBefore', );
        deal(WBTC, ALICE, collAmts);
        _collateralizePosition(ALICE, pos, poolWBTC, collAmts, bytes(''));
        _borrow(ALICE, pos, poolWETH, borrAmts, bytes(''));
        uint healthBefore = initCore.getPosHealthCurrent_e18(pos);
        console2.log('HealthBefore', healthBefore);

        // change mode
        // expectRevert POSITION_NOT_HEALTHY(#300)
        _changeMode(ALICE, pos, 1, bytes('#300'));
    }

    function testMintAndBurn(uint _amount) public {
        _amount = bound(_amount, 1, 1e29);
        address poolWETH = address(lendingPools[WETH]);
        deal(WETH, ALICE, _amount);
        uint shares = _mintPool(ALICE, poolWETH, _amount, bytes(''));
        uint amts = _burnPool(ALICE, poolWETH, shares, bytes(''));
        assertEq(amts, _amount);
    }

    function testAddTooManyCollaterals() public {
        // set collateral max collateral to 3
        _setMaxCollCount(3);
        address poolWETH = address(lendingPools[WETH]);
        address poolWBTC = address(lendingPools[WBTC]);
        address poolWMNT = address(lendingPools[WMNT]);
        address poolUSDT = address(lendingPools[USDT]);

        // create position
        uint posId = _createPos(ALICE, ALICE, 1);

        deal(WETH, ALICE, 1e18);
        deal(WBTC, ALICE, 1e18);
        deal(WMNT, ALICE, 1e18);
        deal(USDT, ALICE, 1e18);

        // add Colateral
        _collateralizePosition(ALICE, posId, poolWETH, 1e18, bytes(''));
        _collateralizePosition(ALICE, posId, poolWBTC, 1e18, bytes(''));
        _collateralizePosition(ALICE, posId, poolWMNT, 1e18, bytes(''));
        // expected revert MAX_COLL_COUNT (#602)
        _collateralizePosition(ALICE, posId, poolUSDT, 1e18, bytes('#602'));
    }

    // Internal Functions
    function _changeMode(address _account, uint _posId, uint16 _mode, bytes memory _revertCode)
        internal
        returns (uint16 currentMode)
    {
        startHoax(_account);
        if (_revertCode.length > 0) {
            vm.expectRevert(_revertCode);
            initCore.setPosMode(_posId, _mode);
            vm.stopPrank();
            return 0;
        } else {
            initCore.setPosMode(_posId, _mode);
            currentMode = positionManager.getPosMode(_posId);
            vm.stopPrank();
        }
    }

    function _approveToken(address _account, address _token, uint _amount) internal {
        startHoax(_account);
        IERC20(_token).approve(address(initCore), _amount);
        vm.stopPrank();
    }

    function _approveTokens(address _account, address[] memory _tokens, uint _amount) internal {
        for (uint i; i < _tokens.length; i = i.uinc()) {
            _approveToken(_account, _tokens[i], _amount);
        }
    }

    function _createPos(address _account, address _viewer, uint16 _mode) internal returns (uint posId) {
        startHoax(_account);

        //actions
        posId = initCore.createPos(_mode, _viewer);
        address owner = positionManager.ownerOf(posId);
        (address viewerAddress, uint16 mode) = positionManager.getPosInfo(posId);
        uint health = initCore.getPosHealthCurrent_e18(posId);
        uint collateralCredit = initCore.getCollateralCreditCurrent_e36(posId);
        uint borrowCredit = initCore.getBorrowCreditCurrent_e36(posId);
        CollateralInfo memory collateralInfo;
        (collateralInfo.pools, collateralInfo.amts, collateralInfo.wLps, collateralInfo.ids, collateralInfo.wLpAmts) =
            positionManager.getPosCollInfo(posId);

        // check conditions
        assertEq(owner, _account);
        assertEq(viewerAddress, _viewer);
        assertEq(mode, _mode);
        assertEq(health, type(uint).max);
        assertEq(collateralCredit, 0);
        assertEq(borrowCredit, 0);
        assertEq(collateralInfo.pools.length, 0);
        assertEq(collateralInfo.amts.length, 0);
        assertEq(collateralInfo.wLps.length, 0);
        assertEq(collateralInfo.ids.length, 0);
        assertEq(collateralInfo.wLpAmts.length, 0);
        vm.stopPrank();
    }

    function _collateralizePosition(address _account, uint _posId, address _pool, uint _amount, bytes memory revertCode)
        internal
        returns (uint amountAfter, bool isInCollateralPools, address[] memory collateralPools)
    {
        startHoax(_account);
        address underlyingToken = ILendingPool(_pool).underlyingToken();
        IERC20(underlyingToken).approve(address(initCore), _amount);

        // gathering info before
        uint amountBefore = positionManager.getCollAmt(_posId, _pool);
        uint collateralCreditBefore = initCore.getCollateralCreditCurrent_e36(_posId);

        // actions
        bytes[] memory calls = new bytes[](3);
        // 1. transfer token to lending pool
        calls[0] = abi.encodeWithSelector(initCore.transferToken.selector, underlyingToken, _pool, _amount);
        // 2. mint token to the position manager
        calls[1] = abi.encodeWithSelector(initCore.mintTo.selector, _pool, address(positionManager));
        // 3. collateralize the position
        calls[2] = abi.encodeWithSelector(initCore.collateralize.selector, _posId, _pool);

        // return early if revert
        if (revertCode.length > 0) {
            vm.expectRevert(revertCode);
            initCore.multicall(calls);
            vm.stopPrank();
            return (0, false, new address[](0));
        } else {
            initCore.multicall(calls);

            // gathering info after
            (address[] memory collateralPoolsAfter,,,,) = positionManager.getPosCollInfo(_posId);
            amountAfter = positionManager.getCollAmt(_posId, _pool);
            bool isInCollateralPoolsAfter = _isListContain(collateralPoolsAfter, _pool);
            uint collateralCreditAfter = initCore.getCollateralCreditCurrent_e36(_posId);

            // check conditions
            assertEq(isInCollateralPoolsAfter, true); // pool should exist in the list
            assertGt(amountAfter, amountBefore); // pool amts should greate than before
            assertGt(collateralCreditAfter, collateralCreditBefore); // Collateral Credit should increase
            vm.stopPrank();
            return (amountAfter, isInCollateralPoolsAfter, collateralPoolsAfter);
        }
    }

    function _decollateralizePosition(
        address _account,
        uint _posId,
        address _pool,
        uint _amount,
        bytes memory revertCode
    ) internal returns (uint amountAfter, bool isInCollateralPools) {
        startHoax(_account);

        // gather info before
        uint collateralCreditBefore = initCore.getCollateralCreditCurrent_e36(_posId);
        uint amountBefore = positionManager.getCollAmt(_posId, _pool);

        // actions
        // return early if revert
        if (revertCode.length > 0) {
            vm.expectRevert(revertCode);
            initCore.decollateralize(_posId, _pool, _amount, _account);
            vm.stopPrank();
            return (0, false);
        } else {
            initCore.decollateralize(_posId, _pool, _amount, _account);

            // (collateralInfoAfter.pools, collateralInfoAfter.amts, , , ) = positionManager.getPosCollInfo(_posId);
            uint collateralCreditAfter = initCore.getCollateralCreditCurrent_e36(_posId);
            amountAfter = positionManager.getCollAmt(_posId, _pool);
            (address[] memory collateralPools,,,,) = positionManager.getPosCollInfo(_posId);
            bool isInCollateralPoolsAfter = _isListContain(collateralPools, _pool);

            // check conditions
            assertLt(amountAfter, amountBefore); // pool amts should be less than before
            assertLt(collateralCreditAfter, collateralCreditBefore); // collateral credits should decreased

            vm.stopPrank();
            return (amountAfter, isInCollateralPoolsAfter);
        }
    }

    function _fundPool(address _pool, uint _amount) internal {
        // funding pool from a whale
        address underlyingToken = ILendingPool(_pool).underlyingToken();
        deal(underlyingToken, WHALE, _amount);
        _mintPool(WHALE, _pool, _amount, bytes(''));
    }

    function _mintPool(address _account, address _pool, uint _amount, bytes memory _revertCode)
        internal
        returns (uint sharesReceive)
    {
        startHoax(_account);
        address underlyingToken = ILendingPool(_pool).underlyingToken();
        IERC20(underlyingToken).approve(address(initCore), _amount);

        // gather info before
        uint totalShares = IERC20(_pool).totalSupply();
        uint cashBefore = ILendingPool(_pool).cash();
        uint sharePriceBefore = _sharePrice(_pool);

        // actions
        bytes[] memory calls = new bytes[](2);
        // 1. transfer token to lending pool
        calls[0] = abi.encodeWithSelector(initCore.transferToken.selector, underlyingToken, _pool, _amount);
        // 2. mint to account
        calls[1] = abi.encodeWithSelector(initCore.mintTo.selector, _pool, _account);

        bytes[] memory results;
        // return early if revert
        if (_revertCode.length > 0) {
            vm.expectRevert(_revertCode);
            results = initCore.multicall(calls);
            vm.stopPrank();
            return 0;
        } else {
            results = initCore.multicall(calls);

            // gather info after
            sharesReceive = abi.decode(results[1], (uint));
            uint cashAfter = ILendingPool(_pool).cash();
            uint totalSharesAfter = IERC20(_pool).totalSupply();
            uint sharePriceAfter = _sharePrice(_pool);

            // check conditions
            assertGe(sharePriceAfter, sharePriceBefore); // share price should equal or greater than before(accrued interest)
            assertEq(totalSharesAfter, totalShares + sharesReceive); // total share increased by the number of shares received
            assertEq(cashAfter, cashBefore + _amount); // cash increased by the input amounts
            vm.stopPrank();
        }
    }

    function _burnPool(address _account, address _pool, uint _shares, bytes memory _revertCode)
        internal
        returns (uint amountReceive)
    {
        startHoax(_account);
        IERC20(_pool).approve(address(initCore), _shares);

        // gather info before
        uint totalShares = IERC20(_pool).totalSupply();
        uint cashBefore = ILendingPool(_pool).cash();
        uint sharePriceBefore = _sharePrice(_pool);

        // actions
        bytes[] memory calls = new bytes[](2);
        // 1. transfer pool's share to lending pool
        calls[0] = abi.encodeWithSelector(initCore.transferToken.selector, _pool, _pool, _shares);
        // 2. burn to account
        calls[1] = abi.encodeWithSelector(initCore.burnTo.selector, _pool, _account);

        bytes[] memory results;
        // return early if revert
        if (_revertCode.length > 0) {
            vm.expectRevert(_revertCode);
            results = initCore.multicall(calls);
            vm.stopPrank();
            return 0;
        } else {
            results = initCore.multicall(calls);

            // gather info after
            amountReceive = abi.decode(results[1], (uint));
            uint cashAfter = ILendingPool(_pool).cash();
            uint totalSharesAfter = IERC20(_pool).totalSupply();
            uint sharePriceAfter = _sharePrice(_pool);

            // check conditions
            assertGe(sharePriceAfter, sharePriceBefore); // share price should equal or greater than before(accrued interest)
            assertEq(totalSharesAfter, totalShares - _shares); // total share decreased by the number of shares burned
            assertEq(cashAfter, cashBefore - amountReceive); // cash decreased by the received amounts
            vm.stopPrank();
        }
    }

    function _borrow(address _account, uint _posId, address _pool, uint _amount, bytes memory _revertCode)
        internal
        returns (uint shares)
    {
        vm.startPrank(_account);
        address underlyingToken = ILendingPool(_pool).underlyingToken();

        PositionInfo memory posInfoBefore;
        // gather info before
        uint16 currentMode = positionManager.getPosMode(_posId);
        posInfoBefore.amount = IERC20(underlyingToken).balanceOf(_account);
        posInfoBefore.borrowCredit = initCore.getBorrowCreditCurrent_e36(_posId);
        posInfoBefore.health = initCore.getPosHealthCurrent_e18(_posId);
        posInfoBefore.debtShares = positionManager.getPosDebtShares(_posId, _pool);
        posInfoBefore.modeDebtShares = riskManager.getModeDebtShares(currentMode, _pool);
        (posInfoBefore.totalInterest, posInfoBefore.lastDebtAmt) = positionManager.getPosBorrExtraInfo(_posId, _pool);

        // return early if revert
        if (_revertCode.length > 0) {
            vm.expectRevert(_revertCode);
            initCore.borrow(_pool, _amount, _posId, _account);
            vm.stopPrank();
            return 0;
        } else {
            // actions
            shares = initCore.borrow(_pool, _amount, _posId, _account);

            // gather info after
            PositionInfo memory posInfoAfter;
            posInfoAfter.amount = IERC20(underlyingToken).balanceOf(_account);
            posInfoAfter.borrowCredit = initCore.getBorrowCreditCurrent_e36(_posId);
            posInfoAfter.health = initCore.getPosHealthCurrent_e18(_posId);
            posInfoAfter.debtShares = positionManager.getPosDebtShares(_posId, _pool);
            posInfoAfter.modeDebtShares = riskManager.getModeDebtShares(currentMode, _pool);
            (posInfoAfter.totalInterest, posInfoAfter.lastDebtAmt) = positionManager.getPosBorrExtraInfo(_posId, _pool);

            // check conditions
            assertLe(posInfoAfter.health, posInfoBefore.health); // position's health should have decreased
            assertGt(posInfoAfter.borrowCredit, posInfoBefore.borrowCredit); // borrow credits should have increased
            assertGt(posInfoAfter.debtShares, posInfoBefore.debtShares); // debt shares should have increased
            assertEq(_amount, posInfoAfter.amount - posInfoBefore.amount); // account should received the token with the borrow amount
            assertEq(posInfoAfter.modeDebtShares, posInfoBefore.modeDebtShares + shares); // mode debt shares should have increased
            assertApproxEqAbs(
                posInfoAfter.lastDebtAmt, posInfoBefore.lastDebtAmt + posInfoAfter.totalInterest + _amount, 1
            );
            console.log('Last Debt Before: ', posInfoBefore.lastDebtAmt);
            console.log('Last Debt After: ', posInfoAfter.lastDebtAmt);
            vm.stopPrank();
        }
    }

    function _repay(address _account, uint _posId, address _pool, uint _shares)
        internal
        returns (bool isInBorrowPoolsAfter)
    {
        startHoax(_account);
        address underlyingToken = ILendingPool(_pool).underlyingToken();
        IERC20(underlyingToken).approve(address(initCore), type(uint).max);

        // gather info before
        PositionInfo memory posInfoBefore;
        uint16 currentMode = positionManager.getPosMode(_posId);
        posInfoBefore.amount = IERC20(underlyingToken).balanceOf(_account);
        posInfoBefore.borrowCredit = initCore.getBorrowCreditCurrent_e36(_posId);
        posInfoBefore.health = initCore.getPosHealthCurrent_e18(_posId);
        posInfoBefore.debtShares = positionManager.getPosDebtShares(_posId, _pool);
        posInfoBefore.modeDebtShares = riskManager.getModeDebtShares(currentMode, _pool);
        (posInfoBefore.totalInterest, posInfoBefore.lastDebtAmt) = positionManager.getPosBorrExtraInfo(_posId, _pool);

        // actions
        uint repayAmounts = initCore.repay(_pool, _shares, _posId);

        // gather info after
        PositionInfo memory posInfoAfter;
        posInfoAfter.amount = IERC20(underlyingToken).balanceOf(_account);
        posInfoAfter.borrowCredit = initCore.getBorrowCreditCurrent_e36(_posId);
        posInfoAfter.health = initCore.getPosHealthCurrent_e18(_posId);
        posInfoAfter.debtShares = positionManager.getPosDebtShares(_posId, _pool);
        posInfoAfter.modeDebtShares = riskManager.getModeDebtShares(currentMode, _pool);
        (posInfoAfter.totalInterest, posInfoAfter.lastDebtAmt) = positionManager.getPosBorrExtraInfo(_posId, _pool);
        (address[] memory borrowPools,) = positionManager.getPosBorrInfo(_posId);
        isInBorrowPoolsAfter = _isListContain(borrowPools, _pool);

        // check conditions
        assertGe(posInfoAfter.health, posInfoBefore.health); // pos's health should have increase (or the same in the case repay too low)
        assertLt(posInfoAfter.borrowCredit, posInfoBefore.borrowCredit); // borrow credits should have increased
        assertLt(posInfoAfter.debtShares, posInfoBefore.debtShares); // debt shares should have increased
        assertEq(repayAmounts, posInfoBefore.amount - posInfoAfter.amount); // account should received the token with the borrow amount
        assertEq(posInfoAfter.modeDebtShares, posInfoBefore.modeDebtShares - _shares); // mode debt shares should have increased
        assertApproxEqAbs(
            posInfoAfter.lastDebtAmt, posInfoBefore.lastDebtAmt + posInfoAfter.totalInterest - repayAmounts, 1
        );
        console.log('RepayAmount: ', repayAmounts);
        console.log('Last Debt Before: ', posInfoBefore.lastDebtAmt);
        console.log('Last Debt After: ', posInfoAfter.lastDebtAmt);
        vm.stopPrank();
    }

    function _liquidate(
        address _account,
        uint _posId,
        uint _debtShares,
        address _inputPool,
        address _outputPool,
        bool isUnderwater,
        bytes memory _expectRevertCode
    ) public returns (address[] memory borrowPools) {
        startHoax(_account);
        uint16 mode = positionManager.getPosMode(_posId);
        IERC20(ILendingPool(_inputPool).underlyingToken()).approve(address(initCore), type(uint).max);

        // gather info before
        PositionInfo memory posBefore;
        posBefore.health = initCore.getPosHealthCurrent_e18(_posId);
        posBefore.modeDebtShares = riskManager.getModeDebtShares(mode, _inputPool);
        posBefore.amount = ILendingPool(_inputPool).debtShareToAmtCurrent(_debtShares);
        posBefore.debtShares = positionManager.getPosDebtShares(_posId, _inputPool);
        uint positionCollateralAmtsBefore = positionManager.getCollAmt(_posId, _outputPool);

        uint shares;
        if (_expectRevertCode.length > 0) {
            if (keccak256(_expectRevertCode) == keccak256(bytes('panic'))) {
                vm.expectRevert();
            } else {
                vm.expectRevert(_expectRevertCode);
            }
            shares = initCore.liquidate(_posId, _inputPool, _debtShares, _outputPool, 0);
            return new address[](0);
        }

        shares = initCore.liquidate(_posId, _inputPool, _debtShares, _outputPool, 0);

        // gather info After
        PositionInfo memory posAfter;
        posAfter.health = initCore.getPosHealthCurrent_e18(_posId);
        posAfter.modeDebtShares = riskManager.getModeDebtShares(mode, _inputPool);
        posAfter.debtShares = positionManager.getPosDebtShares(_posId, _inputPool);
        uint positionCollateralAmtsAfter = positionManager.getCollAmt(_posId, _outputPool);

        uint inputPrice = initOracle.getPrice_e36(ILendingPool(_inputPool).underlyingToken());
        uint outputPrice = initOracle.getPrice_e36(ILendingPool(_outputPool).underlyingToken());

        if (isUnderwater) {
            console.log('is under water');
            assertLe(ILendingPool(_outputPool).toAmtCurrent(shares) * outputPrice, posBefore.amount * inputPrice);
            if (posAfter.health != type(uint).max) assertLt(posAfter.health, posBefore.health);
        } else {
            assertGe(ILendingPool(_outputPool).toAmtCurrent(shares) * outputPrice, posBefore.amount * inputPrice);
            assertGt(posAfter.health, posBefore.health);
            assertEq(posAfter.modeDebtShares, posBefore.modeDebtShares - _debtShares); // mode debt shares should have increased
            assertLe(positionCollateralAmtsAfter, positionCollateralAmtsBefore);
            assertLe(posAfter.debtShares, posBefore.debtShares);
        }
        if (config.getMaxHealthAfterLiq_e18(mode) != type(uint64).max) {
            assertLe(posAfter.health, config.getMaxHealthAfterLiq_e18(mode));
        }
        vm.stopPrank();

        console2.log('USD Input', posBefore.amount * inputPrice);
        console2.log('USD Output', ILendingPool(_outputPool).toAmtCurrent(shares) * outputPrice);
        console2.log('Position Health Before', posBefore.health);
        console2.log('Position Health After', posAfter.health);
    }

    function _transferPosition(address _account, address _to, uint _posId) internal {
        startHoax(_account);
        IERC721(address(positionManager)).transferFrom(_account, _to, _posId);
        address owner = IERC721(address(positionManager)).ownerOf(_posId);
        assertEq(owner, _to);
        vm.stopPrank();
    }

    function _setFixedRateIRM(address pool, uint _fixed_interest_rate_e18) internal {
        startHoax(ADMIN);
        MockFixedRateIRM fixedRateIRM = new MockFixedRateIRM(_fixed_interest_rate_e18);
        ILendingPool(pool).setIrm(address(fixedRateIRM));
        vm.stopPrank();
    }

    function _setPoolConfig(address _pool, PoolConfig memory _poolConfig) internal {
        startHoax(ADMIN);
        config.setPoolConfig(_pool, _poolConfig);
        vm.stopPrank();
    }

    function _setMaxCollCount(uint8 _maxCollCount) internal {
        startHoax(ADMIN);
        positionManager.setMaxCollCount(_maxCollCount);
        vm.stopPrank();
    }

    function _setTargetHealthAfterLiquidation_e18(uint16 _mode, uint64 _targetHealth_e18) internal {
        startHoax(ADMIN);
        config.setMaxHealthAfterLiq_e18(_mode, _targetHealth_e18);
        vm.stopPrank();
    }

    // helper functions
    function _getCollateralBorrowInfo(uint _posId)
        internal
        view
        returns (CollateralInfo memory collateralInfo, BorrowInfo memory borrowInfo)
    {
        (collateralInfo.pools, collateralInfo.amts, collateralInfo.wLps, collateralInfo.ids, collateralInfo.wLpAmts) =
            positionManager.getPosCollInfo(_posId);
        (borrowInfo.pools, borrowInfo.debtShares) = positionManager.getPosBorrInfo(_posId);
    }

    function _sharePrice(address pool) internal view returns (uint sharePrice) {
        uint totalAssets = ILendingPool(pool).totalAssets();
        uint totalSupply = IERC20(pool).totalSupply();
        totalAssets++;
        totalSupply += 1e8;
        sharePrice = (totalAssets * 1e18) / totalSupply;
    }

    function _isListContain(address[] memory _list, address _target) internal pure returns (bool isIn) {
        for (uint i; i < _list.length; i = i.uinc()) {
            if (_list[i] == _target) {
                isIn = true;
                break;
            }
        }
    }

    function _getPoolIndex(address[] memory _pools, address _targetPool) internal pure returns (uint poolIndex) {
        for (uint i; i < _pools.length; i = i.uinc()) {
            if (_pools[i] == _targetPool) {
                poolIndex = i;
                break;
            }
        }
    }
}
