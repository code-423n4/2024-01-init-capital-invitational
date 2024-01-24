pragma solidity ^0.8.19;

import './DeployAll.sol';
import '../../contracts/hook/MoneyMarketHook.sol';
import {PosInfo} from '../../contracts/interfaces/helper/IInitLens.sol';
import {IConfig, PoolConfig, ModeStatus} from '../../contracts/interfaces/core/IConfig.sol';

contract TestInitLens is DeployAll {
    address private constant mUSD_WHALE = 0x10276e18A1987C604741319F64640064F18D503B;

    function setUp() public override {
        DeployAll.setUp();
        _setUpLiquidity();
    }

    function testCheckPosInfo() public {
        vm.startPrank(ALICE);
        uint collAmtUSD = 10_000;
        uint borrowAmtUSD = 1_00;
        (uint posId, uint initPosId) = _createBorrowAndDeposit(ALICE, WETH, collAmtUSD, USDT, borrowAmtUSD);
        PosInfo memory posInfo = initLens.getHookPosInfo(address(moneyMarketHook), ALICE, posId);
        _logPos(posInfo);
        assertEq(posInfo.collCredit_e36, initCore.getCollateralCreditCurrent_e36(initPosId));
        assertEq(posInfo.borrCredit_e36, initCore.getBorrowCreditCurrent_e36(initPosId));
        assertEq(posInfo.health_e18, initCore.getPosHealthCurrent_e18(initPosId));
        assertEq(posInfo.mode, 1);
        assertEq(posInfo.viewer, ALICE);
        assertEq(posInfo.owner, address(moneyMarketHook));
        vm.stopPrank();
    }

    function testAllowBorrowFlag() public {
        address poolUSDT = address(lendingPools[USDT]);
        vm.startPrank(ALICE);
        uint collAmtUSD = 10_000;
        uint borrowAmtUSD = 1_00;
        (uint posId, uint initPosId) = _createBorrowAndDeposit(ALICE, WETH, collAmtUSD, USDT, borrowAmtUSD);
        PosInfo memory posInfo = initLens.getHookPosInfo(address(moneyMarketHook), ALICE, posId);
        // _logPos(posInfo);
        vm.stopPrank();
        uint modeBorrowableAmt;

        // invalid address
        modeBorrowableAmt = initLens.modeBorrowableAmt(1, address(1));
        console2.log('\nInvalid Pool Address');
        console2.log('ModeBorrowAbleAmt:', modeBorrowableAmt);
        assertEq(modeBorrowableAmt, 0);

        // pool canBorrow false
        _setAllowBorrow(poolUSDT, false, 1, true);
        modeBorrowableAmt = initLens.modeBorrowableAmt(1, address(lendingPools[USDT]));
        console2.log('\nPool canBorrow false');
        console2.log('ModeBorrowAbleAmt:', modeBorrowableAmt);
        assertEq(modeBorrowableAmt, 0);

        // mode canBorrow false
        _setAllowBorrow(poolUSDT, true, 1, false);
        modeBorrowableAmt = initLens.modeBorrowableAmt(1, address(lendingPools[USDT]));
        console2.log('\nMode canBorrow false');
        console2.log('ModeBorrowableAmt:', modeBorrowableAmt);
        assertEq(modeBorrowableAmt, 0);

        // mode, pool canBorrow false
        _setAllowBorrow(poolUSDT, false, 1, false);
        modeBorrowableAmt = initLens.modeBorrowableAmt(1, address(lendingPools[USDT]));
        console2.log('\nMode, Pool canBorrow false');
        console2.log('ModeBorrowableAmt:', modeBorrowableAmt);
        assertEq(modeBorrowableAmt, 0);
    }

    function _setAllowBorrow(address _pool, bool _poolBorrow, uint16 _mode, bool _modeBorrow) internal {
        vm.startPrank(ADMIN);
        PoolConfig memory poolConfig = config.getPoolConfig(_pool);
        poolConfig.canBorrow = _poolBorrow;
        config.setPoolConfig(_pool, poolConfig);
        assertEq(config.getPoolConfig(_pool).canBorrow, _poolBorrow);
        ModeStatus memory modeStatus = config.getModeStatus(_mode);
        modeStatus.canBorrow = _modeBorrow;
        config.setModeStatus(_mode, modeStatus);
        assertEq(config.getModeStatus(_mode).canBorrow, _modeBorrow);
        vm.stopPrank();
    }

    function testModePosBorrowAmt() public {
        uint collAmtUSD = 10_000;
        uint borrowAmtUSD = 1_00;
        uint borrowAmt = _priceToTokenAmt(USDT, borrowAmtUSD);
        address poolUSDT = address(lendingPools[USDT]);

        // configuration
        address[] memory pools = new address[](1);
        pools[0] = address(lendingPools[USDT]);
        uint128[] memory ceilAmts = new uint128[](1);

        vm.startPrank(ALICE);
        (uint posId,) = _createBorrowAndDeposit(ALICE, WETH, collAmtUSD, USDT, borrowAmtUSD);
        vm.stopPrank();

        vm.startPrank(ADMIN);
        // set new pool borrow cap
        _setBorrowCap(poolUSDT, 100_000e6);

        // cash > debt ceiling - mode debt > pool's borrow cap - pool's totalDebt
        // borrowable amount shoud be borrowcap - pool's totalDebt
        uint modeBorrowableAmt;
        modeBorrowableAmt = initLens.modeBorrowableAmt(1, address(lendingPools[USDT]));
        PoolConfig memory poolConfig = config.getPoolConfig(poolUSDT);
        uint poolTotalDebt = ILendingPool(poolUSDT).totalDebt();

        // check condition & logs
        assertEq(modeBorrowableAmt, poolConfig.borrowCap - poolTotalDebt);
        console2.log('\n BorrowCap the least');
        console2.log('BorrowCap: ', poolConfig.borrowCap);
        console2.log('BorrowedAmt: ', poolTotalDebt);
        console2.log('BorrowableAmt: ', modeBorrowableAmt);

        // set new mode 1, pool USDT debt ceiling
        ceilAmts[0] = 10_000e6;
        riskManager.setModeDebtCeilingInfo(1, pools, ceilAmts);

        // cash > pool's borrow cap - pool's totalDebt > debt ceiling -mode debt
        // borrowable amount should be debtceiling - borrowed amount
        uint usdtModeDebtCeiling = riskManager.getModeDebtCeilingAmt(1, poolUSDT);
        modeBorrowableAmt = initLens.modeBorrowableAmt(1, address(lendingPools[USDT]));

        // check condition & logs
        assertEq(modeBorrowableAmt, usdtModeDebtCeiling - borrowAmt);
        console2.log('\n DebtCeiling the least');
        console2.log('USDTModeDebtCeil: ', usdtModeDebtCeiling);
        console2.log('BorrowAmt: ', borrowAmt);
        console2.log('BorrowableAmt: ', modeBorrowableAmt);

        // debt ceiling - mode debt >= pool's borrow cap - pool's totalDebt > cash
        _setBorrowCap(poolUSDT, 1_000_000e6);
        ceilAmts[0] = 10_000_000e6;
        riskManager.setModeDebtCeilingInfo(1, pools, ceilAmts);

        // borrowable amount should be leftover cash
        modeBorrowableAmt = initLens.modeBorrowableAmt(1, address(lendingPools[USDT]));
        uint poolCash = ILendingPool(poolUSDT).cash();

        // check condition & logs
        assertEq(modeBorrowableAmt, poolCash);
        console2.log('\nCash the least');
        console2.log('USDTModeDebtCeil: ', usdtModeDebtCeiling);
        console2.log('BorrowAmt: ', borrowAmt);
        console2.log('BorrowableAmt: ', modeBorrowableAmt);
        console2.log('PoolCash: ', poolCash);

        // position's pool borrowable amount should be equal to mode's pool borrowable amount
        uint posBorrowableAmt = initLens.posBorrowableAmt(address(moneyMarketHook), ALICE, posId, poolUSDT);
        console2.log('\nPosBorrowableAmt == ModeBorrowAmt');
        console2.log('PosBorrowAbleAmt: ', posBorrowableAmt);
        console2.log('ModeBorrowableAmt: ', modeBorrowableAmt);
        assertEq(posBorrowableAmt, modeBorrowableAmt);
        vm.stopPrank();
    }

    function testViewerPosInfoAt() public {
        vm.startPrank(ALICE);
        uint[3] memory collAmtUSDs = [uint(10_000), uint(20_000), uint(30_000)];
        uint[3] memory borrowAmtUSDs = [uint(1_000), uint(100), uint(10)];
        uint[] memory initPosIds = new uint[](3);
        for (uint i; i < 3; i++) {
            (, initPosIds[i]) = _createBorrowAndDeposit(ALICE, WETH, collAmtUSDs[i], USDT, borrowAmtUSDs[i]);
        }
        uint viewerLength = positionManager.getViewerPosIdsLength(ALICE);
        for (uint i; i < viewerLength; i++) {
            PosInfo memory posInfo = initLens.viewerPosInfoAt(ALICE, i);
            _logPos(posInfo);
            assertEq(posInfo.collCredit_e36, initCore.getCollateralCreditCurrent_e36(initPosIds[i]));
            assertEq(posInfo.borrCredit_e36, initCore.getBorrowCreditCurrent_e36(initPosIds[i]));
            assertEq(posInfo.health_e18, initCore.getPosHealthCurrent_e18(initPosIds[i]));
            assertEq(posInfo.mode, 1);
            assertEq(posInfo.viewer, ALICE);
            assertEq(posInfo.owner, address(moneyMarketHook));
        }
        vm.stopPrank();
    }

    function _setBorrowCap(address _pool, uint128 _borrCap) internal {
        PoolConfig memory poolConfig = config.getPoolConfig(_pool);
        poolConfig.borrowCap = _borrCap;
        config.setPoolConfig(_pool, poolConfig);
    }

    function _logPos(PosInfo memory _posInfo) internal pure {
        console2.log('PosCollCredit', _posInfo.collCredit_e36);
        console2.log('PosBorrCredit', _posInfo.borrCredit_e36);
        console2.log('PosHealth', _posInfo.health_e18);
        console2.log('PosMode', _posInfo.mode);
        console2.log('PosViewer', _posInfo.viewer);
        console2.log('PosOwner', _posInfo.owner);
    }

    function _createBorrowAndDeposit(
        address _user,
        address _tokenIn,
        uint _usdIn,
        address _tokenBorrow,
        uint _usdBorrow
    ) internal returns (uint posId, uint initPosId) {
        IMoneyMarketHook.DepositParams[] memory depositParams = new IMoneyMarketHook.DepositParams[](1);
        uint amt = _priceToTokenAmt(_tokenIn, _usdIn);
        depositParams[0].pool = address(lendingPools[_tokenIn]);
        depositParams[0].amt = amt;
        IMoneyMarketHook.BorrowParams[] memory borrowedParams = new IMoneyMarketHook.BorrowParams[](1);
        borrowedParams[0].pool = address(lendingPools[_tokenBorrow]);
        borrowedParams[0].amt = _priceToTokenAmt(_tokenBorrow, _usdBorrow);
        borrowedParams[0].to = _user;
        IMoneyMarketHook.OperationParams memory op;
        op.mode = 1;
        op.viewer = _user;
        op.depositParams = depositParams;
        op.borrowParams = borrowedParams;
        uint lastPosId = moneyMarketHook.lastPosIds(_user);
        uint balBf = IERC20(_tokenBorrow).balanceOf(_user);
        vm.startPrank(_user, _user);
        deal(_tokenIn, _user, amt);
        IERC20(_tokenIn).approve(address(moneyMarketHook), type(uint).max);
        (posId, initPosId,) = moneyMarketHook.execute(op);
        vm.stopPrank();
        console.log('posId', posId);
        console.log('initPosId', initPosId);
        assert(moneyMarketHook.initPosIds(_user, posId) == initPosId);
        assert(posId == lastPosId + 1);
        assert(moneyMarketHook.lastPosIds(_user) == lastPosId + 1);
        assert(IERC20(_tokenBorrow).balanceOf(_user) == balBf + borrowedParams[0].amt);
    }
}
