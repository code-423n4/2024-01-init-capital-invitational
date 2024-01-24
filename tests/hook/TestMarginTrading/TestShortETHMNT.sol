pragma solidity ^0.8.19;

import '../TestMarginTradingHelper.sol';

contract TestShortETHMNT is TestMarginTradingHelper {
    address private constant QUOTE_TOKEN = WMNT;
    address private constant BASE_TOKEN = WETH;
    address private collToken = WMNT;
    address private borrToken = WETH;

    function setUp() public override {
        super.setUp();
        vm.startPrank(ADMIN, ADMIN);
        hook.setQuoteAsset(QUOTE_TOKEN, BASE_TOKEN, QUOTE_TOKEN);
        vm.stopPrank();
        _setUpDexLiquidity(QUOTE_TOKEN, BASE_TOKEN);
    }

    function testOpenPosFuzzy(uint _usdIn, uint _usdBorr) public {
        address tokenIn = _usdIn % 2 == 0 ? collToken : borrToken;
        _usdIn = bound(_usdIn, 1, 100_000);
        _usdBorr = bound(_usdBorr, 1, _usdIn);
        _openPos(tokenIn, collToken, borrToken, ALICE, _usdIn, _usdBorr);
    }

    function testTwoUserOpenPosFuzzy(uint _usdIn, uint _usdBorr) public {
        address tokenIn = _usdIn % 2 == 0 ? collToken : borrToken;
        _usdIn = bound(_usdIn, 1, 100_000);
        _usdBorr = bound(_usdBorr, 1, _usdIn);
        _openPos(tokenIn, collToken, borrToken, ALICE, _usdIn, _usdBorr);
        skip(1);
        tokenIn = WETH;
        _usdIn = bound(_usdIn, 1, 100_000);
        _usdBorr = bound(_usdBorr, 1, _usdIn);
        _openPos(tokenIn, collToken, borrToken, BOB, _usdIn, _usdBorr);
    }

    function testIncreasePosDecreaseLevFuzzy(uint _usdIn, uint _usdBorr) public {
        address tokenIn = _usdIn % 2 == 0 ? collToken : borrToken;
        _usdIn = bound(_usdIn, 2, 100_000);
        _usdBorr = bound(_usdBorr, _usdIn, _usdIn);
        uint levBf = (_usdIn + _usdBorr) * 100 / _usdIn;
        (uint posId,) = _openPos(tokenIn, collToken, borrToken, ALICE, _usdIn, _usdBorr);
        skip(1);
        uint usdIn2 = bound(_usdIn, 2, 100_000);
        uint usdBorr2 = bound(_usdBorr, 1, usdIn2);
        tokenIn = _usdIn % 2 == 0 ? collToken : borrToken;
        _increasePos(ALICE, posId, tokenIn, _usdIn, _usdBorr);
        require(levBf >= (_usdIn + _usdBorr + usdBorr2 + usdIn2) * 100 / (_usdIn + usdIn2), 'not decrease leverage');
    }

    function testIncreasePosIncreaseLevFuzzy(uint _usdIn, uint _usdBorr) public {
        address tokenIn = _usdIn % 2 == 0 ? collToken : borrToken;
        _usdIn = bound(_usdIn, 4, 100_000);
        _usdBorr = bound(_usdBorr, 3, _usdIn);
        uint levBf = (_usdIn + _usdBorr) * 100 / _usdIn;
        (uint posId,) = _openPos(tokenIn, collToken, borrToken, ALICE, _usdIn, _usdBorr);
        skip(1);
        uint usdBorr2 = bound(_usdIn, 2, _usdBorr);
        uint usdIn2 = bound(_usdIn, 0, usdBorr2 / 2);
        tokenIn = _usdIn % 2 == 0 ? collToken : borrToken;
        _increasePos(ALICE, posId, tokenIn, usdIn2, _usdBorr);
        require(levBf <= (_usdIn + _usdBorr + usdBorr2 + usdIn2) * 100 / (_usdIn + usdIn2), 'not increase leverage');
    }

    function testAddCollateralFuzzy(uint _usdIn, uint _usdBorr) public {
        address tokenIn = _usdIn % 2 == 0 ? collToken : borrToken;
        _usdIn = bound(_usdIn, 1, 100_000);
        _usdBorr = bound(_usdBorr, 1, _usdIn);
        (uint posId,) = _openPos(tokenIn, collToken, borrToken, ALICE, _usdIn, _usdBorr);
        skip(1);
        _usdIn = bound(_usdIn, 1, 100_000);
        _addCollateral(ALICE, posId, _usdIn);
    }

    function testRepayFuzzy(uint _usdIn, uint _usdBorr, uint _usdRepay) public {
        address tokenIn = _usdIn % 2 == 0 ? collToken : borrToken;
        _usdIn = bound(_usdIn, 10, 100_000);
        _usdBorr = bound(_usdBorr, 5, _usdIn);
        (uint posId,) = _openPos(tokenIn, collToken, borrToken, ALICE, _usdIn, _usdBorr);
        _usdRepay = bound(_usdRepay, 1, _usdBorr / 3);
        _repayDebt(ALICE, posId, _usdRepay);
        skip(1);
        _repayDebt(ALICE, posId, _usdRepay);
        skip(1);
        _repayDebt(ALICE, posId, _usdBorr); // internal function will repay all debt
    }

    function testReducePosSameLevFuzzy(uint _usdIn, uint _usdBorr) public {
        address tokenIn = _usdIn % 2 == 0 ? collToken : borrToken;
        _usdIn = bound(_usdIn, 10, 100_000);
        _usdBorr = bound(_usdBorr, 5, _usdIn);
        (uint posId,) = _openPos(tokenIn, collToken, borrToken, ALICE, _usdIn, _usdBorr);
        skip(1);
        address tokenOut = _usdIn % 2 == 0 ? collToken : borrToken;
        uint percentage = bound(_usdIn, 0.01e18, 1e18);
        _reducePos(ALICE, posId, percentage, tokenOut, false);
    }

    function testClosePosProfit(uint _usdIn, uint _usdBorr) public {
        address tokenIn = _usdIn % 2 == 0 ? borrToken : collToken;
        _usdIn = bound(_usdIn, 10, 100_000);
        _usdBorr = bound(_usdBorr, 5, _usdIn);
        console.log('user token', tokenIn);
        (uint posId,) = _openPos(tokenIn, collToken, borrToken, ALICE, _usdIn, _usdBorr);
        skip(1);
        address tokenOut = tokenIn;
        console.log('user out', tokenOut);
        uint balanceBf = IERC20(tokenOut).balanceOf(ALICE);
        _dumpBaseToken(QUOTE_TOKEN, BASE_TOKEN);
        _closePos(ALICE, posId, tokenOut, false);
        uint balanceAf = IERC20(tokenOut).balanceOf(ALICE);
        uint tokenInAmt = _priceToTokenAmt(tokenOut, _usdIn);
        require(balanceAf - balanceBf > tokenInAmt, 'not win');
    }

    function testClosePosLoss(uint _usdIn, uint _usdBorr) public {
        address tokenIn = _usdIn % 2 == 0 ? borrToken : collToken;
        _usdIn = bound(_usdIn, 10, 100_000);
        _usdBorr = bound(_usdBorr, 5, _usdIn);
        (uint posId,) = _openPos(tokenIn, collToken, borrToken, ALICE, _usdIn, _usdBorr);
        skip(1);
        address tokenOut = tokenIn;
        uint balanceBf = IERC20(tokenOut).balanceOf(ALICE);
        _pumpBaseToken(QUOTE_TOKEN, BASE_TOKEN);
        _closePos(ALICE, posId, tokenOut, false);
        uint balanceAf = IERC20(tokenOut).balanceOf(ALICE);
        uint tokenInAmt = _priceToTokenAmt(tokenIn, _usdIn);
        require(balanceAf - balanceBf < tokenInAmt, 'not loss');
    }

    function testAddStopLoss(uint _usdIn, uint _usdBorr) public {
        address tokenIn = _usdIn % 2 == 0 ? borrToken : collToken;
        _usdIn = bound(_usdIn, 10, 100_000);
        _usdBorr = bound(_usdBorr, 5, _usdIn);
        (uint posId, uint initPosId) = _openPos(tokenIn, collToken, borrToken, ALICE, _usdIn, _usdBorr);
        uint markPrice_e36 = lens.getMarkPrice_e36(collToken, borrToken);
        uint triggerPrice_e36 = markPrice_e36 * 11 / 10; // 110% from mark price
        uint limitPrice_e36 = markPrice_e36 * 111 / 100; // 111% from mark price
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        address tokenOut = _usdIn % 2 == 0 ? borrToken : collToken;
        uint collAmt = positionManager.getCollAmt(initPosId, marginPos.collPool);
        uint size = bound(_usdIn, 0, collAmt); // 1 - 100% of collateral
        _addStopLossOrder(ALICE, posId, triggerPrice_e36, tokenOut, limitPrice_e36, size);
    }

    function testAddTakeProfit(uint _usdIn, uint _usdBorr) public {
        address tokenIn = _usdIn % 2 == 0 ? borrToken : collToken;
        _usdIn = bound(_usdIn, 10, 100_000);
        _usdBorr = bound(_usdBorr, 5, _usdIn);
        (uint posId, uint initPosId) = _openPos(tokenIn, collToken, borrToken, ALICE, _usdIn, _usdBorr);
        uint markPrice_e36 = lens.getMarkPrice_e36(collToken, borrToken);
        uint triggerPrice_e36 = markPrice_e36 * 9 / 10; // 90% from mark price
        uint limitPrice_e36 = markPrice_e36 * 89 / 100; // 89% from mark price
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        address tokenOut = _usdIn % 2 == 0 ? borrToken : collToken;
        uint collAmt = positionManager.getCollAmt(initPosId, marginPos.collPool);
        uint size = bound(_usdIn, 0, collAmt); // 1 - 100% of collateral
        _addTakeProfitOrder(ALICE, posId, triggerPrice_e36, tokenOut, limitPrice_e36, size);
    }

    function testFillOrderTakeProfitNotReachTriggerPrice(uint _usdIn, uint _usdBorr) public {
        address tokenIn = _usdIn % 2 == 0 ? borrToken : collToken;
        _usdIn = bound(_usdIn, 10, 100_000);
        _usdBorr = bound(_usdBorr, 5, _usdIn);
        (uint posId, uint initPosId) = _openPos(tokenIn, collToken, borrToken, ALICE, _usdIn, _usdBorr);
        uint markPrice_e36 = lens.getMarkPrice_e36(collToken, borrToken);
        uint triggerPrice_e36 = markPrice_e36 * 9 / 10; // 90% from mark price
        uint limitPrice_e36 = markPrice_e36 * 89 / 100; // 89% from mark price
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        address tokenOut = _usdIn % 2 == 0 ? borrToken : collToken;
        uint collAmt = positionManager.getCollAmt(initPosId, marginPos.collPool);
        uint orderId = _addTakeProfitOrder(ALICE, posId, triggerPrice_e36, tokenOut, limitPrice_e36, collAmt);
        vm.expectRevert(bytes('#203'));
        hook.fillOrder(orderId);
    }

    function testFillOrderStopLossNotReachTriggerPrice(uint _usdIn, uint _usdBorr) public {
        address tokenIn = _usdIn % 2 == 0 ? borrToken : collToken;
        _usdIn = bound(_usdIn, 10, 100_000);
        _usdBorr = bound(_usdBorr, 5, _usdIn);
        (uint posId, uint initPosId) = _openPos(tokenIn, collToken, borrToken, ALICE, _usdIn, _usdBorr);
        uint markPrice_e36 = lens.getMarkPrice_e36(collToken, borrToken);
        uint triggerPrice_e36 = markPrice_e36 * 11 / 10; // 110% from mark price
        uint limitPrice_e36 = markPrice_e36 * 111 / 100; // 111% from mark price
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        address tokenOut = _usdIn % 2 == 0 ? borrToken : collToken;
        uint collAmt = positionManager.getCollAmt(initPosId, marginPos.collPool);
        uint orderId = _addStopLossOrder(ALICE, posId, triggerPrice_e36, tokenOut, limitPrice_e36, collAmt);
        vm.expectRevert(bytes('#203'));
        hook.fillOrder(orderId);
    }

    function testFillCanceledOrder(uint _usdIn, uint _usdBorr) public {
        address tokenIn = _usdIn % 2 == 0 ? borrToken : collToken;
        _usdIn = bound(_usdIn, 10, 100_000);
        _usdBorr = bound(_usdBorr, 5, _usdIn);
        (uint posId, uint initPosId) = _openPos(tokenIn, collToken, borrToken, ALICE, _usdIn, _usdBorr);
        uint markPrice_e36 = lens.getMarkPrice_e36(collToken, borrToken);
        uint triggerPrice_e36 = markPrice_e36 * 11 / 10; // 110% from mark price
        uint limitPrice_e36 = markPrice_e36 * 111 / 100; // 111% from mark price
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        address tokenOut = _usdIn % 2 == 0 ? borrToken : collToken;
        uint collAmt = positionManager.getCollAmt(initPosId, marginPos.collPool);
        uint orderId = _addStopLossOrder(ALICE, posId, triggerPrice_e36, tokenOut, limitPrice_e36, collAmt);
        vm.startPrank(ALICE, ALICE);
        hook.cancelOrder(posId, orderId);
        vm.expectRevert(bytes('#203'));
        hook.fillOrder(orderId);
        vm.stopPrank();
    }

    function testOpenPosSlippage() public {
        address tokenIn = borrToken;
        uint amtIn = _priceToTokenAmt(tokenIn, 1_000);
        deal(tokenIn, ALICE, amtIn);
        bytes memory data;
        {
            address[] memory path = new address[](2);
            path[0] = borrToken;
            path[1] = collToken;
            data = abi.encode(path, block.timestamp);
        }
        vm.startPrank(ALICE, ALICE);
        IERC20(tokenIn).approve(address(hook), amtIn);
        uint borrAmt = _priceToTokenAmt(borrToken, 1_000);
        vm.expectRevert(bytes('#102'));
        hook.openPos(
            1,
            ALICE,
            tokenIn,
            amtIn,
            address(lendingPools[borrToken]),
            borrAmt,
            address(lendingPools[collToken]),
            data,
            type(uint).max
        );
        vm.stopPrank();
    }

    function testIncreaseSlippage() public {
        address tokenIn = borrToken;
        (uint posId,) = _openPos(tokenIn, collToken, borrToken, ALICE, 1_000, 1_000);
        bytes memory data;
        {
            address[] memory path = new address[](2);
            path[0] = borrToken;
            path[1] = collToken;
            data = abi.encode(path, block.timestamp);
        }
        vm.startPrank(ALICE, ALICE);
        uint borrAmt = _priceToTokenAmt(borrToken, 1_000);
        vm.expectRevert(bytes('#102'));
        hook.increasePos(posId, tokenIn, 0, borrAmt, data, type(uint).max);

        vm.stopPrank();
    }
}
