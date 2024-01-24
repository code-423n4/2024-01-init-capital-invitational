pragma solidity ^0.8.19;

import '../helper/DeployAll.sol';
import '../../contracts/hook/MarginTradingHook.sol';
import '../../contracts/helper/swap_helper/MoeSwapHelper.sol';
import '../../contracts/helper/MarginTradingLens.sol';
import {TransparentUpgradeableProxyReceiveETH} from '../../contracts/common/TransparentUpgradeableProxyReceiveETH.sol';
import {IMoeRouter} from '../../contracts/interfaces/common/moe/IMoeRouter.sol';
import {IMoeFactory} from '../../contracts/interfaces/common/moe/IMoeFactory.sol';

import {IERC721} from '@openzeppelin-contracts/token/ERC721/IERC721.sol';

contract TestMarginTradingHelper is DeployAll {
    uint internal constant ONE_E18 = 1e18;
    MarginTradingHook public hook;
    MoeSwapHelper public swapHelper;
    MarginTradingLens public lens;

    address private constant QUOTE_TOKEN = USDT;
    address private constant BASE_TOKEN = WETH;

    address private constant QUOTE_TOKEN_2 = WMNT;
    address private constant BASE_TOKEN_2 = WETH;

    function setUp() public virtual override {
        super.setUp();
        MarginTradingHook hook_impl =
            new MarginTradingHook(address(initCore), address(positionManager), WMNT, address(accessControlManager));
        swapHelper = new MoeSwapHelper(0xeaEE7EE68874218c3558b40063c42B82D3E7232a);
        hook = MarginTradingHook(
            address(
                new TransparentUpgradeableProxyReceiveETH(address(hook_impl), address(proxyAdmin), abi.encodeWithSelector(MarginTradingHook.initialize.selector, address(swapHelper)))
            )
        );
        lens = new MarginTradingLens(address(hook));
        vm.startPrank(ADMIN, ADMIN);
        hook.setQuoteAsset(QUOTE_TOKEN, BASE_TOKEN, QUOTE_TOKEN);
        hook.setQuoteAsset(QUOTE_TOKEN_2, BASE_TOKEN_2, QUOTE_TOKEN_2);
        vm.stopPrank();
        _setUpLiquidity();
    }

    function testOpenPos() public {
        _setUpDexLiquidity(QUOTE_TOKEN, BASE_TOKEN);
        address tokenIn = USDT;
        address collToken = WETH;
        address borrToken = USDT;
        _openPos(tokenIn, collToken, borrToken, ALICE, 10_000, 10_000);
    }

    function testIncreasePos() public {
        _setUpDexLiquidity(QUOTE_TOKEN, BASE_TOKEN);
        address tokenIn = USDT;
        address collToken = WETH;
        address borrToken = USDT;
        (uint posId,) = _openPos(tokenIn, collToken, borrToken, ALICE, 10_000, 10_000);
        _increasePos(ALICE, posId, tokenIn, 20_000, 10_000);
    }

    function testAddCollateral() public {
        _setUpDexLiquidity(QUOTE_TOKEN, BASE_TOKEN);
        address tokenIn = USDT;
        address collToken = WETH;
        address borrToken = USDT;
        (uint posId,) = _openPos(tokenIn, collToken, borrToken, ALICE, 10_000, 10_000);
        _addCollateral(ALICE, posId, 10_000);
    }

    function testRemoveCollateral() public {
        _setUpDexLiquidity(QUOTE_TOKEN, BASE_TOKEN);
        address tokenIn = USDT;
        address collToken = WETH;
        address borrToken = USDT;
        (uint posId,) = _openPos(tokenIn, collToken, borrToken, ALICE, 10_000, 10_000);
        _addCollateral(ALICE, posId, 10_000);
        _removeCollateral(ALICE, posId, 10_000, false);
    }

    function testRepayDebt() public {
        _setUpDexLiquidity(QUOTE_TOKEN, BASE_TOKEN);
        address tokenIn = USDT;
        address collToken = WETH;
        address borrToken = USDT;
        (uint posId,) = _openPos(tokenIn, collToken, borrToken, ALICE, 10_000, 10_000);
        _repayDebt(ALICE, posId, 5_000);
    }

    function testClosePos() public {
        _setUpDexLiquidity(QUOTE_TOKEN, BASE_TOKEN);
        address tokenIn = USDT;
        address collToken = WETH;
        address borrToken = USDT;
        (uint posId,) = _openPos(tokenIn, collToken, borrToken, ALICE, 10_000, 10_000);
        _closePos(ALICE, posId, QUOTE_TOKEN, false);
    }

    function testReducePos() public {
        _setUpDexLiquidity(QUOTE_TOKEN, BASE_TOKEN);
        address tokenIn = USDT;
        address collToken = WETH;
        address borrToken = USDT;
        (uint posId,) = _openPos(tokenIn, collToken, borrToken, ALICE, 10_000, 10_000);
        _reducePos(ALICE, posId, 0.5e18, collToken, false);
    }

    function testUpdateStopLossOrder() public {
        _setUpDexLiquidity(QUOTE_TOKEN, BASE_TOKEN);
        address tokenIn = USDT;
        address collToken = WETH;
        address borrToken = USDT;
        (uint posId, uint initPosId) = _openPos(tokenIn, collToken, borrToken, ALICE, 10_000, 10_000);
        uint markPrice_e36 = lens.getMarkPrice_e36(collToken, borrToken);
        uint triggerPrice_e36 = markPrice_e36 * 9 / 10; // 90% from mark price
        uint limitPrice_e36 = markPrice_e36 * 89 / 100; // 89% from mark price
        address tokenOut = WETH;
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        uint orderId = _addStopLossOrder(
            ALICE,
            posId,
            triggerPrice_e36,
            tokenOut,
            limitPrice_e36,
            positionManager.getCollAmt(initPosId, marginPos.collPool)
        );
        _updateOrder(ALICE, posId, orderId, triggerPrice_e36, tokenOut, limitPrice_e36, 1000);
    }

    function testUpdateTakeProfiOrder() public {
        _setUpDexLiquidity(QUOTE_TOKEN, BASE_TOKEN);
        address tokenIn = USDT;
        address collToken = WETH;
        address borrToken = USDT;
        (uint posId, uint initPosId) = _openPos(tokenIn, collToken, borrToken, ALICE, 10_000, 10_000);
        uint markPrice_e36 = lens.getMarkPrice_e36(collToken, borrToken);
        uint triggerPrice_e36 = markPrice_e36 * 110 / 10; // 110% from mark price
        uint limitPrice_e36 = markPrice_e36 * 109 / 100; // 109% from mark price
        address tokenOut = WETH;
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        uint orderId = _addTakeProfitOrder(
            ALICE,
            posId,
            triggerPrice_e36,
            tokenOut,
            limitPrice_e36,
            positionManager.getCollAmt(initPosId, marginPos.collPool)
        );
        _updateOrder(ALICE, posId, orderId, triggerPrice_e36, tokenOut, limitPrice_e36, 1000);
    }

    function testFillOrderTakeProfitCollTokenOut() public {
        _setUpDexLiquidity(QUOTE_TOKEN, BASE_TOKEN);
        address tokenIn = USDT;
        address collToken = WETH;
        address borrToken = USDT;
        (uint posId, uint initPosId) = _openPos(tokenIn, collToken, borrToken, ALICE, 10_000, 10_000);
        uint markPrice_e36 = lens.getMarkPrice_e36(collToken, borrToken);
        uint triggerPrice_e36 = markPrice_e36; // from mark price (trigger instantly)
        uint limitPrice_e36 = markPrice_e36 * 109 / 100; // 109% from mark price
        address tokenOut = WETH;
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        uint orderId = _addTakeProfitOrder(
            ALICE,
            posId,
            triggerPrice_e36,
            tokenOut,
            limitPrice_e36,
            positionManager.getCollAmt(initPosId, marginPos.collPool)
        );
        uint fillAmt = _fillOrder(BOB, orderId);
        console.log('return val', fillAmt * initOracle.getPrice_e36(tokenOut) / 1e36);
    }

    function testFillOrderTakeProfitBorrTokenOut() public {
        _setUpDexLiquidity(QUOTE_TOKEN, BASE_TOKEN);
        address tokenIn = USDT;
        address collToken = WETH;
        address borrToken = USDT;
        (uint posId, uint initPosId) = _openPos(tokenIn, collToken, borrToken, ALICE, 10_000, 10_000);
        uint markPrice_e36 = lens.getMarkPrice_e36(collToken, borrToken);
        uint triggerPrice_e36 = markPrice_e36; // from mark price (trigger instantly)
        uint limitPrice_e36 = markPrice_e36 * 109 / 100; // 109% from mark price
        address tokenOut = borrToken;
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        uint orderId = _addTakeProfitOrder(
            ALICE,
            posId,
            triggerPrice_e36,
            tokenOut,
            limitPrice_e36,
            positionManager.getCollAmt(initPosId, marginPos.collPool)
        );
        uint fillAmt = _fillOrder(BOB, orderId);
        console.log('return val', fillAmt * initOracle.getPrice_e36(tokenOut) / 1e36);
    }

    function testFillOrderStopLossCollTokenOut() public {
        _setUpDexLiquidity(QUOTE_TOKEN, BASE_TOKEN);
        address tokenIn = USDT;
        address collToken = WETH;
        address borrToken = USDT;
        (uint posId, uint initPosId) = _openPos(tokenIn, collToken, borrToken, ALICE, 10_000, 10_000);
        uint markPrice_e36 = lens.getMarkPrice_e36(collToken, borrToken);
        uint triggerPrice_e36 = markPrice_e36; // from mark price (trigger instantly)
        uint limitPrice_e36 = markPrice_e36 * 99 / 100; // 109% from mark price
        address tokenOut = collToken;
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        uint orderId = _addStopLossOrder(
            ALICE,
            posId,
            triggerPrice_e36,
            tokenOut,
            limitPrice_e36,
            positionManager.getCollAmt(initPosId, marginPos.collPool)
        );
        uint fillAmt = _fillOrder(BOB, orderId);
        console.log('return val', fillAmt * initOracle.getPrice_e36(tokenOut) / 1e36);
    }

    function testFillOrderStopLossBorrTokenOut() public {
        _setUpDexLiquidity(QUOTE_TOKEN, BASE_TOKEN);
        address tokenIn = USDT;
        address collToken = WETH;
        address borrToken = USDT;
        (uint posId, uint initPosId) = _openPos(tokenIn, collToken, borrToken, ALICE, 10_000, 10_000);
        uint markPrice_e36 = lens.getMarkPrice_e36(collToken, borrToken);
        uint triggerPrice_e36 = markPrice_e36; // from mark price (trigger instantly)
        uint limitPrice_e36 = markPrice_e36 * 0.99e18 / 1e18; // 99% from mark price
        address tokenOut = borrToken;
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        console.log(markPrice_e36, 'mark price');
        console.log(triggerPrice_e36, 'trigger price');
        console.log(limitPrice_e36, 'limit price');
        {
            uint posValAtLimitPrice = ILendingPool(marginPos.collPool).toAmtCurrent(
                positionManager.getCollAmt(initPosId, marginPos.collPool)
            ) * limitPrice_e36 / 1e36;
            uint borrVal = ILendingPool(marginPos.borrPool).debtShareToAmtCurrent(
                positionManager.getPosDebtShares(initPosId, marginPos.borrPool)
            );
            console.log(
                ' pos val at mark price',
                ILendingPool(marginPos.collPool).toAmtCurrent(positionManager.getCollAmt(initPosId, marginPos.collPool))
                    * markPrice_e36 / 1e36
            );
            console.log('pos val at limit price', posValAtLimitPrice);
            console.log('return val', posValAtLimitPrice - borrVal, 'expected');
        }
        uint orderId = _addStopLossOrder(
            ALICE,
            posId,
            triggerPrice_e36,
            tokenOut,
            limitPrice_e36,
            positionManager.getCollAmt(initPosId, marginPos.collPool)
        );
        uint fillAmt = _fillOrder(BOB, orderId);
        console.log('return val', fillAmt, 'received');
    }

    function testUseNative() external {
        _setUpDexLiquidity(QUOTE_TOKEN_2, BASE_TOKEN_2);
        address tokenIn = WMNT;
        address collToken = WETH;
        address borrToken = WMNT;
        uint amtIn = _priceToTokenAmt(tokenIn, 10_000);
        uint borrAmt = _priceToTokenAmt(borrToken, 10_000);
        deal(tokenIn, ALICE, 2 * amtIn);
        deal(ALICE, 100_000 * 1e18);
        vm.startPrank(ALICE, ALICE);
        IERC20(tokenIn).approve(address(hook), amtIn);
        bytes memory data;
        {
            address[] memory path = new address[](2);
            path[0] = borrToken;
            path[1] = collToken;
            data = abi.encode(path, block.timestamp);
        }
        address collPool = address(lendingPools[collToken]);
        address borrPool = address(lendingPools[borrToken]);
        IERC20(tokenIn).approve(address(hook), type(uint).max);
        (uint posId,,) =
            hook.openPos{value: amtIn / 2}(1, ALICE, tokenIn, amtIn, borrPool, borrAmt, collPool, data, ONE_E18);
        hook.increasePos{value: amtIn / 2}(posId, tokenIn, amtIn, borrAmt, data, ONE_E18);
        hook.repayDebt{value: borrAmt}(posId, 1);
        vm.stopPrank();
        _reducePos(ALICE, posId, 0.7e18, WMNT, true);
        amtIn = _priceToTokenAmt(WMNT, 10_000);
        borrAmt = _priceToTokenAmt(WETH, 10_000);
        vm.startPrank(ALICE, ALICE);
        {
            address[] memory path = new address[](2);
            path[0] = WETH;
            path[1] = WMNT;
            data = abi.encode(path, block.timestamp);
        }
        (posId,,) = hook.openPos{value: amtIn}(
            1, ALICE, tokenIn, amtIn, address(lendingPools[WETH]), borrAmt, address(lendingPools[WMNT]), data, ONE_E18
        );
        IERC20(WMNT).approve(address(hook), 0);
        hook.addCollateral{value: amtIn}(posId, amtIn);
        vm.stopPrank();
        _removeCollateral(ALICE, posId, 100, true);
        _closePos(ALICE, posId, WMNT, true);
    }

    function _openPos(
        address _tokenIn,
        address _collToken,
        address _borrToken,
        address _user,
        uint _amtIn,
        uint _borrAmt
    ) internal returns (uint posId, uint initPosId) {
        // NOTE: _amtIn and _borrAmt are in USD
        // using this approch to avoid stack too deep error
        _amtIn = _priceToTokenAmt(_tokenIn, _amtIn);
        _borrAmt = _priceToTokenAmt(_borrToken, _borrAmt);
        deal(_tokenIn, _user, _amtIn);
        vm.startPrank(_user, _user);
        IERC20(_tokenIn).approve(address(hook), _amtIn);
        bytes memory data;
        {
            address[] memory path = new address[](2);
            path[0] = _borrToken;
            path[1] = _collToken;
            data = abi.encode(path, block.timestamp);
        }
        address collPool = address(lendingPools[_collToken]);
        address borrPool = address(lendingPools[_borrToken]);

        (posId, initPosId,) = hook.openPos(1, _user, _tokenIn, _amtIn, borrPool, _borrAmt, collPool, data, ONE_E18);
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        require(marginPos.collPool == collPool, 'coll pool is correct');
        require(marginPos.borrPool == borrPool, 'coll pool is correct');
        (address baseAsset, address quoteAsset) = hook.getBaseAssetAndQuoteAsset(_borrToken, _collToken);
        require(marginPos.quoteAsset == quoteAsset, 'quote asset is not correct');
        require(marginPos.baseAsset == baseAsset, 'base asset is not correct');
        require(positionManager.getCollAmt(initPosId, marginPos.collPool) > 0, 'coll not increase');
        uint debtShares = positionManager.getPosDebtShares(initPosId, marginPos.borrPool);
        require(debtShares > 0, 'borr not increase');
        uint posDebt = ILendingPool(marginPos.borrPool).debtShareToAmtCurrent(debtShares);
        require(posDebt >= _borrAmt, 'borr not increase');
        assertApproxEqAbs(posDebt, _borrAmt, 10, 'borr not equal');
        (address viewerAddress, uint16 mode) = positionManager.getPosInfo(initPosId);
        require(_user == viewerAddress, 'viewer not set');
        require(1 == mode, 'mode not set');

        vm.stopPrank();
    }

    function _increasePos(address _user, uint _posId, address _tokenIn, uint _usdIn, uint _borrUsd) internal {
        uint initPosId = hook.initPosIds(_user, _posId);
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        uint amt = _priceToTokenAmt(_tokenIn, _usdIn);
        vm.startPrank(_user, _user);
        deal(_tokenIn, _user, amt);
        address collToken = ILendingPool(marginPos.collPool).underlyingToken();
        address borrToken = ILendingPool(marginPos.borrPool).underlyingToken();
        uint borrAmt = _priceToTokenAmt(borrToken, _borrUsd);
        bytes memory data;
        {
            address[] memory path = new address[](2);
            path[0] = borrToken;
            path[1] = collToken;
            data = abi.encode(path, block.timestamp);
        }
        uint collAmtBf = positionManager.getCollAmt(initPosId, marginPos.collPool);
        uint debtSharesBf = positionManager.getPosDebtShares(initPosId, marginPos.borrPool);
        IERC20(_tokenIn).approve(address(hook), amt);
        hook.increasePos(_posId, _tokenIn, amt, borrAmt, data, ONE_E18);
        vm.stopPrank();
        require(positionManager.getCollAmt(initPosId, marginPos.collPool) > collAmtBf, 'coll not increase');
        require(
            ILendingPool(marginPos.borrPool).debtShareToAmtCurrent(
                (positionManager.getPosDebtShares(initPosId, marginPos.borrPool) - debtSharesBf)
            ) >= borrAmt,
            'borr not increase correctly'
        );
    }

    function _addCollateral(address _user, uint _posId, uint _usd) internal {
        uint initPosId = hook.initPosIds(_user, _posId);
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        uint heathBf_e18 = initCore.getPosHealthCurrent_e18(initPosId);
        address collToken = ILendingPool(marginPos.collPool).underlyingToken();
        uint amt = _priceToTokenAmt(collToken, _usd);
        deal(collToken, _user, amt);
        uint collAmtBf = positionManager.getCollAmt(initPosId, marginPos.collPool);
        vm.startPrank(ALICE, ALICE);
        IERC20(collToken).approve(address(hook), amt);
        hook.addCollateral(_posId, amt);
        require(initCore.getPosHealthCurrent_e18(initPosId) > heathBf_e18, 'health not increase');
        require(positionManager.getCollAmt(initPosId, marginPos.collPool) > collAmtBf, 'coll not increase');
        vm.stopPrank();
    }

    function _removeCollateral(address _user, uint _posId, uint _usd, bool _returnNative) internal {
        uint initPosId = hook.initPosIds(_user, _posId);
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        uint heathBf_e18 = initCore.getPosHealthCurrent_e18(initPosId);
        address collToken = ILendingPool(marginPos.collPool).underlyingToken();
        uint amt = _priceToTokenAmt(collToken, _usd);
        uint collAmtBf = positionManager.getCollAmt(initPosId, marginPos.collPool);
        uint collAmtToRemove = ILendingPool(marginPos.collPool).toShares(amt);
        uint userBalBf = _returnNative ? _user.balance : IERC20(collToken).balanceOf(_user);
        vm.startPrank(_user, _user);
        hook.removeCollateral(_posId, collAmtToRemove, _returnNative);
        require(initCore.getPosHealthCurrent_e18(initPosId) < heathBf_e18, 'health not decrease');
        require(
            collAmtBf - positionManager.getCollAmt(initPosId, marginPos.collPool) == collAmtToRemove,
            'coll not decrease'
        );
        vm.stopPrank();
        uint balanceAf = _returnNative ? _user.balance : IERC20(collToken).balanceOf(_user);
        require(balanceAf - userBalBf > 0, 'not receive token out');
    }

    function _repayDebt(address _user, uint _posId, uint _usd) internal {
        uint initPosId = hook.initPosIds(_user, _posId);
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        vm.startPrank(_user, _user);
        uint heathBf_e18 = initCore.getPosHealthCurrent_e18(initPosId);
        address borrToken = ILendingPool(marginPos.borrPool).underlyingToken();
        uint amt = _priceToTokenAmt(borrToken, _usd);
        uint debtShares = ILendingPool(marginPos.borrPool).debtAmtToShareCurrent(amt);
        uint debtSharesBf = positionManager.getPosDebtShares(initPosId, marginPos.borrPool);
        debtShares = debtShares > debtSharesBf ? debtSharesBf : debtShares;
        amt = ILendingPool(marginPos.borrPool).debtShareToAmtCurrent(debtShares);
        deal(borrToken, _user, amt);
        IERC20(borrToken).approve(address(hook), amt);
        hook.repayDebt(_posId, debtShares);
        require(initCore.getPosHealthCurrent_e18(initPosId) > heathBf_e18, 'health not increase');
        require(
            debtSharesBf - debtShares == positionManager.getPosDebtShares(initPosId, marginPos.borrPool),
            'debt not decrease'
        );
        vm.stopPrank();
    }

    function _closePos(address _user, uint _posId, address _tokenOut, bool _returnNative) internal {
        uint initPosId = hook.initPosIds(_user, _posId);
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        vm.startPrank(_user, _user);
        address[] memory path = new address[](2);
        path[0] = ILendingPool(marginPos.collPool).underlyingToken();
        path[1] = ILendingPool(marginPos.borrPool).underlyingToken();
        bytes memory data = abi.encode(path, block.timestamp);
        uint userBalBf = _returnNative ? _user.balance : IERC20(_tokenOut).balanceOf(_user);
        hook.reducePos(
            _posId,
            positionManager.getCollAmt(initPosId, marginPos.collPool),
            positionManager.getPosDebtShares(initPosId, marginPos.borrPool),
            _tokenOut,
            0,
            _returnNative,
            data,
            0
        );
        require(initCore.getPosHealthCurrent_e18(initPosId) == type(uint).max, 'health not decrease');
        require(positionManager.getCollAmt(initPosId, marginPos.collPool) == 0, 'coll not decrease');
        require(positionManager.getPosDebtShares(initPosId, marginPos.borrPool) == 0, 'debt not decrease');
        vm.stopPrank();
        uint balanceAf = _returnNative ? _user.balance : IERC20(_tokenOut).balanceOf(_user);
        require(balanceAf - userBalBf > 0, 'not receive token out');
    }

    function _reducePos(address _user, uint _posId, uint percent_e18, address _tokenOut, bool _returnNative) internal {
        uint initPosId = hook.initPosIds(_user, _posId);
        MarginPos memory marginPos = hook.getMarginPos(initPosId);
        bytes memory data;
        {
            address[] memory path = new address[](2);
            path[0] = ILendingPool(marginPos.collPool).underlyingToken();
            path[1] = ILendingPool(marginPos.borrPool).underlyingToken();
            data = abi.encode(path, block.timestamp);
        }
        vm.startPrank(_user, _user);
        uint debtSharesBf = positionManager.getPosDebtShares(initPosId, marginPos.borrPool);
        uint collAmtBf = positionManager.getCollAmt(initPosId, marginPos.collPool);
        uint reduceDebtShares = debtSharesBf * percent_e18 / 1e18;
        uint reduceCollAmt = collAmtBf * percent_e18 / 1e18;
        uint userBalBf = _returnNative ? _user.balance : IERC20(_tokenOut).balanceOf(_user);
        hook.reducePos(_posId, reduceCollAmt, reduceDebtShares, _tokenOut, 1, _returnNative, data, ONE_E18);
        vm.stopPrank();
        require(collAmtBf - positionManager.getCollAmt(_posId, marginPos.collPool) > reduceCollAmt, 'coll not increase');
        require(
            debtSharesBf - positionManager.getPosDebtShares(_posId, marginPos.borrPool) > reduceDebtShares,
            'debt not increase'
        );
        uint balanceAf = _returnNative ? _user.balance : IERC20(_tokenOut).balanceOf(_user);
        require(balanceAf - userBalBf > 0, 'not receive token out');
    }

    function _addTakeProfitOrder(
        address _user,
        uint _posId,
        uint _triggerPrice_e36,
        address _tokenOut,
        uint _limitPrice_e36,
        uint _size
    ) internal returns (uint orderId) {
        uint lastOrderId = hook.lastOrderId();
        uint lengthBf = hook.getPosOrdersLength(hook.initPosIds(_user, _posId));
        vm.startPrank(_user, _user);
        orderId = hook.addTakeProfitOrder(_posId, _triggerPrice_e36, _tokenOut, _limitPrice_e36, _size);
        vm.stopPrank();
        Order memory order = hook.getOrder(orderId);
        require(hook.getPosOrdersLength(hook.initPosIds(_user, _posId)) == lengthBf + 1, 'order not added');
        require(hook.lastOrderId() == lastOrderId + 1, 'invalid last order id');
        require(order.initPosId == hook.initPosIds(_user, _posId), 'invalid pos id');
        require(order.orderType == OrderType.TakeProfit, 'invalid order type');
        require(order.triggerPrice_e36 == _triggerPrice_e36, 'invalid trigger price');
        require(order.tokenOut == _tokenOut, 'invalid token out');
        require(order.limitPrice_e36 == _limitPrice_e36, 'invalid limit price');
        require(order.collAmt == _size, 'invalid size');
        require(order.status == OrderStatus.Active, 'invalid status');
    }

    function _addStopLossOrder(
        address _user,
        uint _posId,
        uint _triggerPrice_e36,
        address _tokenOut,
        uint _limitPrice_e36,
        uint _size
    ) internal returns (uint orderId) {
        uint lastOrderId = hook.lastOrderId();
        uint lengthBf = hook.getPosOrdersLength(hook.initPosIds(_user, _posId));
        vm.startPrank(_user, _user);
        orderId = hook.addStopLossOrder(_posId, _triggerPrice_e36, _tokenOut, _limitPrice_e36, _size);
        vm.stopPrank();
        Order memory order = hook.getOrder(orderId);
        require(hook.getPosOrdersLength(hook.initPosIds(_user, _posId)) == lengthBf + 1, 'order not added');
        require(hook.lastOrderId() == lastOrderId + 1, 'invalid last order id');
        require(order.initPosId == hook.initPosIds(_user, _posId), 'invalid pos id');
        require(order.orderType == OrderType.StopLoss, 'invalid order type');
        require(order.triggerPrice_e36 == _triggerPrice_e36, 'invalid trigger price');
        require(order.tokenOut == _tokenOut, 'invalid token out');
        require(order.limitPrice_e36 == _limitPrice_e36, 'invalid limit price');
        require(order.collAmt == _size, 'invalid size');
        require(order.status == OrderStatus.Active, 'invalid status');
    }

    function _fillOrder(address _user, uint _orderId) internal returns (uint) {
        (address fillToken, uint fillAmt, address repayToken, uint repayAmt) = lens.getFillOrderInfoCurrent(_orderId);
        Order memory order = hook.getOrder(_orderId);
        MarginPos memory marginPos = hook.getMarginPos(order.initPosId);
        if (fillToken == repayToken) {
            deal(fillToken, _user, fillAmt + repayAmt);
        } else {
            deal(fillToken, _user, fillAmt);
            deal(repayToken, _user, repayAmt);
        }
        uint collPoolBf = IERC20(marginPos.collPool).balanceOf(_user);
        uint posCollAmtBf = positionManager.getCollAmt(order.initPosId, marginPos.collPool);
        uint tokenOutBf = IERC20(order.tokenOut).balanceOf(order.recipient);
        vm.startPrank(_user, _user);
        IERC20(fillToken).approve(address(hook), type(uint).max);
        IERC20(repayToken).approve(address(hook), type(uint).max);
        hook.fillOrder(_orderId);
        require(IERC20(marginPos.collPool).balanceOf(_user) - collPoolBf == order.collAmt, 'not receive coll');
        require(
            posCollAmtBf - order.collAmt == positionManager.getCollAmt(order.initPosId, marginPos.collPool),
            'coll not decrease'
        );
        require(IERC20(order.tokenOut).balanceOf(order.recipient) - tokenOutBf == fillAmt, 'not receive token out');
        require(hook.getOrder(_orderId).status == OrderStatus.Filled, 'order not filled');
        vm.stopPrank();
        return fillAmt;
    }

    function _updateOrder(
        address _user,
        uint _posId,
        uint _orderId,
        uint _triggerPrice_e36,
        address _tokenOut,
        uint _limitPrice_e36,
        uint _size
    ) internal {
        vm.startPrank(_user, _user);
        hook.updateOrder(_posId, _orderId, _triggerPrice_e36, _tokenOut, _limitPrice_e36, _size);
        vm.stopPrank();
        Order memory order = hook.getOrder(_orderId);
        require(order.initPosId == hook.initPosIds(_user, _posId), 'invalid pos id');
        require(order.triggerPrice_e36 == _triggerPrice_e36, 'invalid trigger price');
        require(order.tokenOut == _tokenOut, 'invalid token out');
        require(order.limitPrice_e36 == _limitPrice_e36, 'invalid limit price');
        require(order.collAmt == _size, 'invalid size');
    }

    function _setUpDexLiquidity(address _tokenA, address _tokenB) internal {
        uint amtA = _priceToTokenAmt(_tokenA, 100_000_000);
        uint amtB = _priceToTokenAmt(_tokenB, 100_000_000);

        deal(_tokenA, TREASURY, amtA);
        deal(_tokenB, TREASURY, amtB);

        address router = swapHelper.ROUTER();

        vm.startPrank(TREASURY, TREASURY);
        IERC20(_tokenA).approve(router, amtA);
        IERC20(_tokenB).approve(router, amtB);
        IMoeRouter(router).addLiquidity(_tokenA, _tokenB, amtA, amtB, 0, 0, TREASURY, block.timestamp);
        vm.stopPrank();
    }

    function _pumpBaseToken(address _quoteToken, address _baseToken) internal {
        address router = swapHelper.ROUTER();
        address factory = IMoeRouter(router).factory();
        address pair = IMoeFactory(factory).getPair(_quoteToken, _baseToken);
        uint amtA = IERC20(_quoteToken).balanceOf(pair) * 10 / 100;

        deal(_quoteToken, TREASURY, amtA);
        vm.startPrank(TREASURY, TREASURY);
        IERC20(_quoteToken).approve(router, amtA);
        address[] memory path = new address[](2);
        path[0] = _quoteToken;
        path[1] = _baseToken;
        IMoeRouter(router).swapExactTokensForTokens(amtA, 0, path, TREASURY, block.timestamp);
        vm.stopPrank();
    }

    function _dumpBaseToken(address _quoteToken, address _baseToken) internal {
        address router = swapHelper.ROUTER();
        address factory = IMoeRouter(router).factory();
        address pair = IMoeFactory(factory).getPair(_quoteToken, _baseToken);
        uint amtA = IERC20(_baseToken).balanceOf(pair) * 10 / 100;

        deal(_baseToken, TREASURY, amtA);
        vm.startPrank(TREASURY, TREASURY);
        IERC20(_baseToken).approve(router, amtA);
        address[] memory path = new address[](2);
        path[0] = _baseToken;
        path[1] = _quoteToken;
        IMoeRouter(router).swapExactTokensForTokens(amtA, 0, path, TREASURY, block.timestamp);
        vm.stopPrank();
    }
}
