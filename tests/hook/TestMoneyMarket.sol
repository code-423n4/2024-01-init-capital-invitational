// SPDX-License-Identifier: None
pragma solidity ^0.8.19;

import '../helper/DeployAll.sol';
import '../../contracts/hook/MoneyMarketHook.sol';

contract TestMoneyMarket is DeployAll {
    address private constant mUSD_WHALE = 0x9FceDEd3a0c838d1e73E88ddE466f197DF379f70;

    function setUp() public override {
        DeployAll.setUp();
        _setUpLiquidity();
        _setUpWhitelistedHelpers();
    }

    function testCreatePos() public {
        vm.startPrank(ALICE);
        uint positionNumbers = 3;
        uint[] memory initPosIds = new uint[](positionNumbers);
        for (uint i; i < initPosIds.length; i++) {
            (, initPosIds[i]) = moneyMarketHook.createPos(1, ALICE);
        }
        uint lastIds = moneyMarketHook.lastPosIds(ALICE);
        assertEq(lastIds, positionNumbers);
        assertEq(lastIds, positionManager.nextNonces(address(moneyMarketHook)));
        for (uint i = 1; i <= lastIds; i++) {
            assertEq(moneyMarketHook.initPosIds(ALICE, i), initPosIds[i - 1]);
            console2.log('MoneyMarket Init Pos ID: ', moneyMarketHook.initPosIds(ALICE, i));
            console2.log('Init Pos ID: ', initPosIds[i - 1]);
        }
        vm.stopPrank();
    }

    function testDepositSimple() public {
        _createAndDeposit(ALICE, USDT, 100_000);
        _createAndDeposit(BOB, WMNT, 100_000_000);
    }

    function testDepositNativeAndWNative() public {
        IMoneyMarketHook.DepositParams[] memory depositParams = new IMoneyMarketHook.DepositParams[](1);
        uint amt = _priceToTokenAmt(WMNT, 2000);
        depositParams[0].pool = address(lendingPools[WMNT]);
        depositParams[0].amt = 0;
        IMoneyMarketHook.OperationParams memory op;
        op.depositParams = depositParams;
        op.mode = 1;

        uint lastPosId = moneyMarketHook.lastPosIds(ALICE);
        vm.startPrank(ALICE, ALICE);
        deal(ALICE, amt * 3);
        (uint posId, uint initPosId,) = moneyMarketHook.execute{value: amt}(op);
        vm.stopPrank();
        console.log('posId', posId);
        console.log('initPosId', initPosId);
        assert(moneyMarketHook.initPosIds(ALICE, posId) == initPosId);
        assert(posId == lastPosId + 1);
        assert(moneyMarketHook.lastPosIds(ALICE) == lastPosId + 1);

        // deposit wnative
        depositParams[0].amt = amt;
        vm.startPrank(ALICE, ALICE);
        deal(WMNT, ALICE, amt);
        IERC20(WMNT).approve(address(moneyMarketHook), type(uint).max);
        (posId, initPosId,) = moneyMarketHook.execute(op);
        vm.stopPrank();

        // deposit both
        vm.startPrank(ALICE, ALICE);
        deal(WMNT, ALICE, amt);
        (posId, initPosId,) = moneyMarketHook.execute{value: amt}(op);
        vm.stopPrank();
    }

    function testDepositMUSD() public {
        IMoneyMarketHook.DepositParams[] memory depositParams = new IMoneyMarketHook.DepositParams[](1);
        uint amt = 10_000 * 10 ** 18;
        startHoax(mUSD_WHALE);
        IERC20(mUSD).transfer(ALICE, amt);
        depositParams[0].pool = address(lendingPools[USDY]);
        depositParams[0].amt = amt;
        depositParams[0].rebaseHelperParams.helper = address(musdusdyWrapHelper);
        depositParams[0].rebaseHelperParams.tokenIn = mUSD;

        IMoneyMarketHook.OperationParams memory op;
        op.depositParams = depositParams;
        op.mode = 1;

        uint lastPosId = moneyMarketHook.lastPosIds(ALICE);
        vm.startPrank(ALICE, ALICE);
        IERC20(mUSD).approve(address(moneyMarketHook), type(uint).max);
        (uint posId, uint initPosId,) = moneyMarketHook.execute(op);
        vm.stopPrank();
        console.log('posId', posId);
        console.log('initPosId', initPosId);
        assert(moneyMarketHook.initPosIds(ALICE, posId) == initPosId);
        assert(posId == lastPosId + 1);
        assert(moneyMarketHook.lastPosIds(ALICE) == lastPosId + 1);
        assert(positionManager.getCollAmt(initPosId, depositParams[0].pool) > 0);
    }

    function testDepositNotWhitelistHelper() public {
        IMoneyMarketHook.DepositParams[] memory depositParams = new IMoneyMarketHook.DepositParams[](1);
        uint amt = 10_000 * 10 ** 18;
        startHoax(mUSD_WHALE);
        IERC20(mUSD).transfer(ALICE, amt);
        depositParams[0].pool = address(lendingPools[USDY]);
        depositParams[0].amt = amt;
        depositParams[0].rebaseHelperParams.helper = address(0x1234);
        depositParams[0].rebaseHelperParams.tokenIn = mUSD;

        IMoneyMarketHook.OperationParams memory op;
        op.depositParams = depositParams;
        op.mode = 1;

        vm.startPrank(ALICE, ALICE);
        IERC20(mUSD).approve(address(moneyMarketHook), type(uint).max);
        vm.expectRevert(bytes('#107'));
        (uint posId, uint initPosId,) = moneyMarketHook.execute(op);
        vm.stopPrank();
        console.log('posId', posId);
        console.log('initPosId', initPosId);
    }

    function testWithdrawSimple() public {
        uint posId = _createAndDeposit(ALICE, WETH, 2000);
        uint balBf = IERC20(WETH).balanceOf(ALICE);
        uint amt = _priceToTokenAmt(WETH, 2000);
        IMoneyMarketHook.WithdrawParams[] memory withdrawParams = new IMoneyMarketHook.WithdrawParams[](1);
        withdrawParams[0].pool = address(lendingPools[WETH]);
        withdrawParams[0].shares =
            positionManager.getCollAmt(moneyMarketHook.initPosIds(ALICE, posId), withdrawParams[0].pool);
        withdrawParams[0].to = ALICE;
        IMoneyMarketHook.OperationParams memory op;
        op.posId = posId;
        op.withdrawParams = withdrawParams;
        vm.startPrank(ALICE, ALICE);
        moneyMarketHook.execute(op);
        vm.stopPrank();
        console.log('balBf', balBf + amt);
        console.log('balAf', IERC20(WETH).balanceOf(ALICE));
        assert(IERC20(WETH).balanceOf(ALICE) == balBf + amt);
    }

    function testWithdrawNative() public {
        uint posId = _createAndDeposit(ALICE, WMNT, 2000);
        uint balBf = ALICE.balance;
        uint amt = _priceToTokenAmt(WMNT, 2000);
        IMoneyMarketHook.WithdrawParams[] memory withdrawParams = new IMoneyMarketHook.WithdrawParams[](1);
        withdrawParams[0].pool = address(lendingPools[WMNT]);
        withdrawParams[0].shares =
            positionManager.getCollAmt(moneyMarketHook.initPosIds(ALICE, posId), withdrawParams[0].pool);
        withdrawParams[0].to = address(moneyMarketHook);
        IMoneyMarketHook.OperationParams memory op;
        op.posId = posId;
        op.withdrawParams = withdrawParams;
        op.returnNative = true;
        vm.startPrank(ALICE, ALICE);
        moneyMarketHook.execute(op);
        vm.stopPrank();
        console.log('balBf', balBf + amt);
        console.log('balAf', ALICE.balance);
        assert(ALICE.balance == balBf + amt);
    }

    function testWithdrawNativeWrongToAddress() public {
        uint posId = _createAndDeposit(ALICE, WMNT, 2000);
        uint balBf = ALICE.balance;
        uint amt = _priceToTokenAmt(WMNT, 2000);
        IMoneyMarketHook.WithdrawParams[] memory withdrawParams = new IMoneyMarketHook.WithdrawParams[](1);
        withdrawParams[0].pool = address(lendingPools[WMNT]);
        withdrawParams[0].shares =
            positionManager.getCollAmt(moneyMarketHook.initPosIds(ALICE, posId), withdrawParams[0].pool);
        withdrawParams[0].to = address(0); // set to wrong address, suppose to be the money market hook address
        IMoneyMarketHook.OperationParams memory op;
        op.posId = posId;
        op.withdrawParams = withdrawParams;
        op.returnNative = true;
        vm.startPrank(ALICE, ALICE);
        moneyMarketHook.execute(op);
        vm.stopPrank();
        console.log('balBf', balBf + amt);
        console.log('balAf', ALICE.balance);
        assert(ALICE.balance == balBf + amt);
    }

    function testWithdrawMUSD() public {
        // deposit
        IMoneyMarketHook.DepositParams[] memory depositParams = new IMoneyMarketHook.DepositParams[](1);
        uint amt = 10_000 * 10 ** 18;
        startHoax(mUSD_WHALE);
        IERC20(mUSD).transfer(ALICE, amt);
        depositParams[0].pool = address(lendingPools[USDY]);
        depositParams[0].amt = amt;
        depositParams[0].rebaseHelperParams.helper = address(musdusdyWrapHelper);
        depositParams[0].rebaseHelperParams.tokenIn = mUSD;

        IMoneyMarketHook.OperationParams memory op;
        op.depositParams = depositParams;
        op.mode = 1;

        uint lastPosId = moneyMarketHook.lastPosIds(ALICE);
        vm.startPrank(ALICE, ALICE);
        IERC20(mUSD).approve(address(moneyMarketHook), type(uint).max);
        (uint posId, uint initPosId,) = moneyMarketHook.execute(op);
        vm.stopPrank();
        console.log('posId', posId);
        console.log('initPosId', initPosId);
        assert(moneyMarketHook.initPosIds(ALICE, posId) == initPosId);
        assert(posId == lastPosId + 1);
        assert(moneyMarketHook.lastPosIds(ALICE) == lastPosId + 1);
        assert(positionManager.getCollAmt(initPosId, depositParams[0].pool) > 0);

        // withdraw
        uint balBf = IERC20(mUSD).balanceOf(ALICE);
        IMoneyMarketHook.OperationParams memory op2;
        IMoneyMarketHook.WithdrawParams[] memory withdrawParams = new IMoneyMarketHook.WithdrawParams[](1);
        withdrawParams[0].pool = address(lendingPools[USDY]);
        withdrawParams[0].shares =
            positionManager.getCollAmt(moneyMarketHook.initPosIds(ALICE, posId), withdrawParams[0].pool);
        withdrawParams[0].to = ALICE;
        withdrawParams[0].rebaseHelperParams.helper = address(musdusdyWrapHelper);
        withdrawParams[0].rebaseHelperParams.tokenIn = USDY;
        op2.posId = posId;
        op2.withdrawParams = withdrawParams;
        vm.startPrank(ALICE, ALICE);
        moneyMarketHook.execute(op2);
        vm.stopPrank();
        console.log('balBf', balBf + amt);
        console.log('balAf', IERC20(mUSD).balanceOf(ALICE));
        assert(IERC20(mUSD).balanceOf(ALICE) >= balBf + amt - 1);
        assert(positionManager.getCollAmt(initPosId, depositParams[0].pool) == 0);
    }

    function testDepositAndBorrowSimple() public {
        _createBorrowAndDeposit(ALICE, ALICE, WETH, 10_000, USDT, 2_000);
    }

    function testDepositAndBorrowNative() public {
        uint balBf = ALICE.balance;
        uint borrowAmt = _priceToTokenAmt(WMNT, 2000);
        _createBorrowNativeAndDeposit(ALICE, address(moneyMarketHook), WETH, 10_000, 2000);

        // check native balance
        console.log('Native Balance Before', balBf);
        console.log('Native Borrow Amt', borrowAmt);
        console.log('Native Balance After', ALICE.balance);
        assertEq(ALICE.balance, balBf + borrowAmt);
    }

    function testDepositAndBorrowNativeWrongAddress() public {
        uint balBf = ALICE.balance;
        uint borrowAmt = _priceToTokenAmt(WMNT, 2000);
        _createBorrowNativeAndDeposit(ALICE, BOB, WETH, 10_000, 2000);

        // check native balance
        console.log('Native Balance Before', balBf);
        console.log('Native Borrow Amt', borrowAmt);
        console.log('Native Balance After', ALICE.balance);
        assertEq(ALICE.balance, balBf + borrowAmt);
    }

    function testRepay() public {
        (uint posId,) = _createBorrowAndDeposit(ALICE, ALICE, WETH, 10_000, USDT, 2_000);
        uint balBf = IERC20(USDT).balanceOf(ALICE);
        uint debtShares = _priceToTokenAmt(USDT, 1_000);
        IMoneyMarketHook.RepayParams[] memory repayParams = new IMoneyMarketHook.RepayParams[](1);
        repayParams[0].pool = address(lendingPools[USDT]);
        repayParams[0].shares = debtShares;
        IMoneyMarketHook.OperationParams memory op;
        op.posId = posId;
        op.repayParams = repayParams;
        vm.startPrank(ALICE, ALICE);
        IERC20(USDT).approve(address(moneyMarketHook), type(uint).max);
        moneyMarketHook.execute(op);
        vm.stopPrank();
        assert(IERC20(USDT).balanceOf(ALICE) == balBf - debtShares);
    }

    function testRepayMoreThanDebtShares() public {
        (uint posId, uint initPosId) = _createBorrowAndDeposit(ALICE, ALICE, WETH, 10_000, USDT, 2_000);
        uint balBf = IERC20(USDT).balanceOf(ALICE);
        uint posDebtShares = positionManager.getPosDebtShares(initPosId, address(lendingPools[USDT]));
        console2.log('Position DebtShares: ', posDebtShares);

        // pay shares amt parameter greater than position debt shares
        IMoneyMarketHook.RepayParams[] memory repayParams = new IMoneyMarketHook.RepayParams[](1);
        repayParams[0].pool = address(lendingPools[USDT]);
        repayParams[0].shares = posDebtShares + 1000;

        IMoneyMarketHook.OperationParams memory op;
        op.posId = posId;
        op.repayParams = repayParams;
        vm.startPrank(ALICE, ALICE);
        IERC20(USDT).approve(address(moneyMarketHook), type(uint).max);
        moneyMarketHook.execute(op);
        vm.stopPrank();

        // should repay only position debt shares amount
        assertEq(IERC20(USDT).balanceOf(ALICE), balBf - posDebtShares);
    }

    function testRepayAfterTimeSkip() public {
        (uint posId, uint initPosId) = _createBorrowAndDeposit(ALICE, ALICE, WETH, 10_000, USDT, 2_000);
        uint balBf = IERC20(USDT).balanceOf(ALICE);
        uint debtShares = _priceToTokenAmt(USDT, 1_000);
        IMoneyMarketHook.RepayParams[] memory repayParams = new IMoneyMarketHook.RepayParams[](1);
        repayParams[0].pool = address(lendingPools[USDT]);
        repayParams[0].shares = debtShares;
        IMoneyMarketHook.OperationParams memory op;
        op.posId = posId;
        op.repayParams = repayParams;
        skip(1);
        vm.startPrank(ALICE, ALICE);
        IERC20(USDT).approve(address(moneyMarketHook), type(uint).max);
        moneyMarketHook.execute(op);
        vm.stopPrank();
        assert(IERC20(USDT).balanceOf(ALICE) < balBf - debtShares); // NOTE: 1 debtShares > 1 asset
    }

    function testChangeCollateral() public {
        (uint posId, uint initPosId) = _createBorrowAndDeposit(ALICE, ALICE, WETH, 10_000, WBTC, 2_000);
        // withdraw WETH and deposit WMNT
        IMoneyMarketHook.WithdrawParams[] memory withdrawParams = new IMoneyMarketHook.WithdrawParams[](1);
        withdrawParams[0].pool = address(lendingPools[WETH]);
        withdrawParams[0].shares = positionManager.getCollAmt(initPosId, withdrawParams[0].pool);
        withdrawParams[0].to = ALICE;
        IMoneyMarketHook.DepositParams[] memory depositParams = new IMoneyMarketHook.DepositParams[](1);
        depositParams[0].pool = address(lendingPools[WMNT]);
        depositParams[0].amt = _priceToTokenAmt(WMNT, 100_000_000_000);
        IMoneyMarketHook.OperationParams memory op;
        op.posId = posId;
        op.withdrawParams = withdrawParams;
        op.depositParams = depositParams;
        vm.startPrank(ALICE, ALICE);
        deal(WMNT, ALICE, depositParams[0].amt);
        IERC20(WMNT).approve(address(moneyMarketHook), type(uint).max);
        moneyMarketHook.execute(op);
        vm.stopPrank();
    }

    function testChangeBorrow() public {
        (uint posId, uint initPosId) = _createBorrowAndDeposit(ALICE, ALICE, WETH, 10_000, WBTC, 2_000);
        uint debtShares = _priceToTokenAmt(WBTC, 2_000);
        IMoneyMarketHook.RepayParams[] memory repayParams = new IMoneyMarketHook.RepayParams[](1);
        repayParams[0].pool = address(lendingPools[WBTC]);
        repayParams[0].shares = debtShares;
        IMoneyMarketHook.BorrowParams[] memory borrowedParams = new IMoneyMarketHook.BorrowParams[](1);
        borrowedParams[0].pool = address(lendingPools[USDT]);
        borrowedParams[0].amt = _priceToTokenAmt(USDT, 1_000);
        borrowedParams[0].to = ALICE;
        IMoneyMarketHook.OperationParams memory op;
        op.posId = posId;
        op.repayParams = repayParams;
        op.borrowParams = borrowedParams;
        vm.startPrank(ALICE, ALICE);
        IERC20(WBTC).approve(address(moneyMarketHook), type(uint).max);
        moneyMarketHook.execute(op);
        vm.stopPrank();
        assert(IERC20(WBTC).balanceOf(ALICE) == 0);
    }

    function testChangeMode() public {
        (uint posId, uint initPosId) = _createBorrowAndDeposit(ALICE, ALICE, WETH, 10_000, WBTC, 2_000);
        IMoneyMarketHook.OperationParams memory op;
        op.posId = posId;
        op.mode = 2;
        vm.startPrank(ALICE, ALICE);
        moneyMarketHook.execute(op);
        vm.stopPrank();
    }

    function testRepayAndChangeMode() public {
        (uint posId, uint initPosId) = _createBorrowAndDeposit(ALICE, ALICE, WETH, 10_000, USDT, 2_000);
        uint debtShares = _priceToTokenAmt(USDT, 2_000);
        IMoneyMarketHook.RepayParams[] memory repayParams = new IMoneyMarketHook.RepayParams[](1);
        repayParams[0].pool = address(lendingPools[USDT]);
        repayParams[0].shares = debtShares;
        IMoneyMarketHook.OperationParams memory op;
        op.repayParams = repayParams;
        op.posId = posId;
        op.mode = 2;
        vm.startPrank(ALICE, ALICE);
        IERC20(USDT).approve(address(moneyMarketHook), type(uint).max);
        moneyMarketHook.execute(op);
        vm.stopPrank();
    }

    function testExecuteAll() public {
        // 1. repay 2000 usdt
        // 2. withdraw 10_000 $WETH
        // 3. change mode to mode 2
        // 3. deposit 100_000_000_000 $WMNT
        // 4. borrow 10_000 $WBTC
        (uint posId, uint initPosId) = _createBorrowAndDeposit(ALICE, ALICE, WETH, 10_000, USDT, 2_000);
        uint debtShares = _priceToTokenAmt(USDT, 2_000);
        IMoneyMarketHook.RepayParams[] memory repayParams = new IMoneyMarketHook.RepayParams[](1);
        repayParams[0].pool = address(lendingPools[USDT]);
        repayParams[0].shares = debtShares;
        IMoneyMarketHook.WithdrawParams[] memory withdrawParams = new IMoneyMarketHook.WithdrawParams[](1);
        withdrawParams[0].pool = address(lendingPools[WETH]);
        withdrawParams[0].shares = positionManager.getCollAmt(initPosId, withdrawParams[0].pool);
        withdrawParams[0].to = ALICE;
        IMoneyMarketHook.DepositParams[] memory depositParams = new IMoneyMarketHook.DepositParams[](1);
        depositParams[0].pool = address(lendingPools[WMNT]);
        depositParams[0].amt = 0;
        IMoneyMarketHook.BorrowParams[] memory borrowedParams = new IMoneyMarketHook.BorrowParams[](1);
        borrowedParams[0].pool = address(lendingPools[WBTC]);
        borrowedParams[0].amt = _priceToTokenAmt(WBTC, 10_000);
        borrowedParams[0].to = ALICE;

        IMoneyMarketHook.OperationParams memory op;
        op.posId = posId;
        op.repayParams = repayParams;
        op.withdrawParams = withdrawParams;
        op.mode = 2;
        op.borrowParams = borrowedParams;
        op.depositParams = depositParams;
        uint nativeAmt = _priceToTokenAmt(WMNT, 100_000_000_000);
        vm.startPrank(ALICE, ALICE);
        IERC20(USDT).approve(address(moneyMarketHook), type(uint).max);
        deal(ALICE, nativeAmt);
        moneyMarketHook.execute{value: nativeAmt}(op);
        vm.stopPrank();
    }

    function _createAndDeposit(address _user, address _token, uint _usd) internal returns (uint posId) {
        IMoneyMarketHook.DepositParams[] memory depositParams = new IMoneyMarketHook.DepositParams[](1);
        uint amt = _priceToTokenAmt(_token, _usd);
        depositParams[0].pool = address(lendingPools[_token]);
        depositParams[0].amt = amt;
        IMoneyMarketHook.OperationParams memory op;
        op.depositParams = depositParams;
        op.mode = 1;

        uint lastPosId = moneyMarketHook.lastPosIds(_user);
        vm.startPrank(_user, _user);
        deal(_token, _user, amt);
        IERC20(_token).approve(address(moneyMarketHook), type(uint).max);
        uint initPosId;
        (posId, initPosId,) = moneyMarketHook.execute(op);
        vm.stopPrank();
        console.log('posId', posId);
        console.log('initPosId', initPosId);
        assert(moneyMarketHook.initPosIds(_user, posId) == initPosId);
        assert(posId == lastPosId + 1);
        assert(moneyMarketHook.lastPosIds(_user) == lastPosId + 1);
    }

    function _createBorrowAndDeposit(
        address _user,
        address _to,
        address _tokenIn,
        uint _usdIn,
        address _tokenBorrow,
        uint _usdBorrow
    ) internal returns (uint posId, uint initPosId) {
        IMoneyMarketHook.DepositParams[] memory depositParams = new IMoneyMarketHook.DepositParams[](1);
        depositParams[0].pool = address(lendingPools[_tokenIn]);
        depositParams[0].amt = _priceToTokenAmt(_tokenIn, _usdIn);
        IMoneyMarketHook.BorrowParams[] memory borrowedParams = new IMoneyMarketHook.BorrowParams[](1);
        borrowedParams[0].pool = address(lendingPools[_tokenBorrow]);
        borrowedParams[0].amt = _priceToTokenAmt(_tokenBorrow, _usdBorrow);
        borrowedParams[0].to = _to;
        IMoneyMarketHook.OperationParams memory op;
        op.mode = 1;
        op.depositParams = depositParams;
        op.borrowParams = borrowedParams;
        uint lastPosId = moneyMarketHook.lastPosIds(_user);
        uint balBf = IERC20(_tokenBorrow).balanceOf(_to);
        vm.startPrank(_user, _user);
        deal(_tokenIn, _user, _priceToTokenAmt(_tokenIn, _usdIn));
        IERC20(_tokenIn).approve(address(moneyMarketHook), type(uint).max);
        (posId, initPosId,) = moneyMarketHook.execute(op);
        vm.stopPrank();
        console.log('posId', posId);
        console.log('initPosId', initPosId);
        assert(moneyMarketHook.initPosIds(_user, posId) == initPosId);
        assert(posId == lastPosId + 1);
        assert(moneyMarketHook.lastPosIds(_user) == lastPosId + 1);
        assert(IERC20(_tokenBorrow).balanceOf(_to) == balBf + borrowedParams[0].amt);
    }

    function _createBorrowNativeAndDeposit(address _user, address _to, address _tokenIn, uint _usdIn, uint _usdBorrow)
        internal
        returns (uint posId, uint initPosId)
    {
        IMoneyMarketHook.DepositParams[] memory depositParams = new IMoneyMarketHook.DepositParams[](1);
        depositParams[0].pool = address(lendingPools[_tokenIn]);
        depositParams[0].amt = _priceToTokenAmt(_tokenIn, _usdIn);
        IMoneyMarketHook.BorrowParams[] memory borrowedParams = new IMoneyMarketHook.BorrowParams[](1);
        borrowedParams[0].pool = address(lendingPools[WMNT]);
        borrowedParams[0].amt = _priceToTokenAmt(WMNT, _usdBorrow);
        borrowedParams[0].to = _to;
        IMoneyMarketHook.OperationParams memory op;
        op.mode = 1;
        op.depositParams = depositParams;
        op.borrowParams = borrowedParams;
        op.returnNative = true;
        uint lastPosId = moneyMarketHook.lastPosIds(_user);
        vm.startPrank(_user, _user);
        deal(_tokenIn, _user, _priceToTokenAmt(_tokenIn, _usdIn));
        IERC20(_tokenIn).approve(address(moneyMarketHook), type(uint).max);
        (posId, initPosId,) = moneyMarketHook.execute(op);
        vm.stopPrank();
        console.log('posId', posId);
        console.log('initPosId', initPosId);

        assert(moneyMarketHook.initPosIds(_user, posId) == initPosId);
        assert(posId == lastPosId + 1);
        assert(moneyMarketHook.lastPosIds(_user) == lastPosId + 1);
    }

    function _setUpWhitelistedHelpers() internal {
        startHoax(ADMIN);
        address[] memory helpers = new address[](1);
        helpers[0] = address(musdusdyWrapHelper);
        moneyMarketHook.setWhitelistedHelpers(helpers, true);
        vm.stopPrank();
    }
}
