pragma solidity ^0.8.19;

import '../helper/DeployAll.sol';
import '@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol';

interface IUniPair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves() external view returns (uint112, uint112, uint32);

    function mint(address to) external returns (uint);
}

contract TestWLp is DeployAll {
    address lp = WETH_USDT_UNI_V2;
    address topHolder = 0xf405F313F3c9bb2807625Ec9f8C2e305c2745766;
    uint constant ONE_E18 = 1e18;

    function setUp() public override {
        super.setUp();
        _setUpLiquidity();
        _setUpWLp();
    }

    function _setUpWLp() internal {
        address[] memory wLps = new address[](1);
        wLps[0] = address(mockWLpUniV2);
        vm.startPrank(ADMIN, ADMIN);
        config.setWhitelistedWLps(wLps, true);
        config.setMaxCollWLpCount(3, 5);
        vm.stopPrank();
        _addLp(topHolder, 1_000_000);
    }

    function _dealLp(address _to, uint _amt) internal {
        vm.startPrank(topHolder, topHolder);
        IERC20(lp).transfer(_to, _amt);
        vm.stopPrank();
    }

    function _addLp(address _to, uint _usd) internal {
        address token0 = IUniPair(lp).token0();
        address token1 = IUniPair(lp).token1();
        uint amt0 = _priceToTokenAmt(token0, _usd);
        uint amt1 = _priceToTokenAmt(token1, _usd);
        deal(token0, _to, amt0);
        deal(token1, _to, amt1);
        vm.startPrank(_to, _to);
        IERC20(token0).transfer(lp, amt0);
        IERC20(token1).transfer(lp, amt1);
        IUniPair(lp).mint(_to);
        vm.stopPrank();
    }

    function _depositLp(address _user, uint _amt, uint _posId) internal {
        // deal lp
        _dealLp(_user, _amt);
        vm.startPrank(_user, _user);
        IERC20(lp).approve(address(initCore), type(uint).max);
        // multicall via core to deposit lp
        bytes[] memory data = new bytes[](3);
        uint96 tokenId = mockWLpUniV2.nextId();
        data[0] = abi.encodeWithSelector(initCore.transferToken.selector, lp, address(wrapCenter), _amt);
        data[1] = abi.encodeWithSelector(
            initCore.callback.selector,
            address(wrapCenter),
            0,
            abi.encodeWithSelector(
                wrapCenter.wrapLp.selector, address(mockWLpUniV2), lp, address(positionManager), new bytes(0)
            )
        );
        data[2] = abi.encodeWithSelector(initCore.collateralizeWLp.selector, _posId, address(mockWLpUniV2), tokenId);

        initCore.multicall(data);
        // check position hold wlp
        assertEq(positionManager.getCollWLpAmt(_posId, address(mockWLpUniV2), tokenId), _amt);
        (,, address[] memory wLps, uint[][] memory ids, uint[][] memory wLpAmts) =
            positionManager.getPosCollInfo(_posId);
        assertEq(wLps.length, 1);
        assertEq(wLps[0], address(mockWLpUniV2));
        assertEq(ids[0].length, 1);
        assertEq(ids[0][0], tokenId);
        assertEq(wLpAmts[0].length, 1);
        assertEq(wLpAmts[0][0], _amt);
        vm.stopPrank();
    }

    function _openPositionWithLp(address _user, uint _amt) internal returns (uint posId) {
        vm.startPrank(_user, _user);
        posId = initCore.createPos(3, ALICE);
        vm.stopPrank();
        _depositLp(_user, _amt, posId);
    }

    function _addRewards(uint _wlpId) internal {
        address[] memory tokens = mockWLpUniV2.rewardTokens(_wlpId);
        uint[] memory amts = new uint[](tokens.length);
        for (uint i; i < tokens.length; i++) {
            amts[i] = 1e18;
            deal(tokens[i], address(this), amts[i]);
            IERC20(tokens[i]).approve(address(mockWLpUniV2), type(uint).max);
        }
        mockWLpUniV2.addRewards(_wlpId, amts);
    }

    function testOraclePrice() public {
        _openPositionWithLp(ALICE, 100000000);
        uint price = mockWLpUniV2.calculatePrice_e36(1, address(initOracle));
        uint totalSupply = IERC20(lp).totalSupply();
        (uint112 r0, uint112 r1,) = IUniPair(lp).getReserves();
        uint priceSpot = (r0 * initOracle.getPrice_e36(IUniPair(lp).token0())) / totalSupply;
        priceSpot += (r1 * initOracle.getPrice_e36(IUniPair(lp).token1())) / totalSupply;
        console.log(price, 'price wlp');
        console.log(priceSpot, 'price spot');
    }

    function testDepositSimple() public {
        _openPositionWithLp(ALICE, 100000000);
    }

    function testDepositAndBorrow() public {
        uint posId = _openPositionWithLp(ALICE, 100000000);
        vm.startPrank(ALICE, ALICE);
        initCore.borrow(address(lendingPools[WETH]), 1, posId, ALICE);
        vm.stopPrank();
    }

    function testDepositExcessMaxCollCount() public {
        uint posId = _openPositionWithLp(ALICE, 100000000);
        _addLp(ALICE, 1_000_000);
        uint totalLp = IERC20(lp).balanceOf(ALICE);
        vm.startPrank(ALICE, ALICE);
        IERC20(lp).approve(address(mockWLpUniV2), type(uint).max);
        for (uint i; i < MAX_COLL_COUNT; i++) {
            uint wLpId = mockWLpUniV2.wrap(lp, totalLp / MAX_COLL_COUNT, ALICE, '');
            mockWLpUniV2.safeTransferFrom(ALICE, address(positionManager), wLpId);
            if (i == MAX_COLL_COUNT - 1) {
                vm.expectRevert(bytes('#602'));
            }
            initCore.collateralizeWLp(posId, address(mockWLpUniV2), wLpId);
        }
        vm.stopPrank();
    }

    function testTwoUserDepositLp() public {
        uint amt = 100000000;
        uint alicePosId = _openPositionWithLp(ALICE, amt);
        uint bobPosId = _openPositionWithLp(BOB, amt);
        assertEq(positionManager.getCollWLpAmt(alicePosId, address(mockWLpUniV2), 2), 0);
        assertEq(positionManager.getCollWLpAmt(bobPosId, address(mockWLpUniV2), 1), 0);
        assertEq(initCore.getCollateralCreditCurrent_e36(alicePosId), initCore.getCollateralCreditCurrent_e36(bobPosId));
    }

    function testTwoUserDepositLpDuplicatedId() public {
        uint amt = 100000000;
        uint alicePosId = _openPositionWithLp(ALICE, amt);
        vm.startPrank(BOB, BOB);
        uint bobPosId = initCore.createPos(3, BOB);
        // bob try deposit alice's lp
        vm.expectRevert(bytes('#604'));
        initCore.collateralizeWLp(bobPosId, address(mockWLpUniV2), 1);
        vm.stopPrank();
    }

    function testCollateralizeFakeLp() public {
        uint amt = 100000000;
        _dealLp(ALICE, amt);
        vm.startPrank(ALICE, ALICE);
        IERC20(lp).approve(address(mockWLpUniV2), type(uint).max);
        uint alicePosId = initCore.createPos(3, ALICE);
        // 1. fake id
        vm.expectRevert(bytes('#500'));
        initCore.collateralizeWLp(alicePosId, address(mockWLpUniV2), 1);
        // 2. fake wlp
        vm.expectRevert(bytes('#501'));
        initCore.collateralizeWLp(alicePosId, address(this), 1);
        // 3. not transfer wlp
        uint wLpId = mockWLpUniV2.wrap(lp, amt, ALICE, '');
        vm.expectRevert(bytes('#104'));
        initCore.collateralizeWLp(alicePosId, address(mockWLpUniV2), 1);
        vm.stopPrank();
    }

    function testTwoUserDepositLpThenAliceWithdraw() public {
        uint amt = 100000000;
        uint withdrawAmt = amt / 2;
        uint alicePosId = _openPositionWithLp(ALICE, amt);
        uint bobPosId = _openPositionWithLp(BOB, amt);
        vm.startPrank(ALICE, ALICE);
        initCore.decollateralizeWLp(alicePosId, address(mockWLpUniV2), 1, withdrawAmt, ALICE);
        vm.stopPrank();
        assertEq(positionManager.getCollWLpAmt(alicePosId, address(mockWLpUniV2), 2), 0);
        assertEq(positionManager.getCollWLpAmt(bobPosId, address(mockWLpUniV2), 1), 0);
        assertEq(positionManager.getCollWLpAmt(alicePosId, address(mockWLpUniV2), 1), amt - withdrawAmt);
        assertEq(IERC20(lp).balanceOf(ALICE), withdrawAmt);
    }

    function testTwoUserDepositLpThenAliceWithdrawAll() public {
        uint amt = 100000000;
        uint alicePosId = _openPositionWithLp(ALICE, amt);
        uint bobPosId = _openPositionWithLp(BOB, amt);
        vm.startPrank(ALICE, ALICE);
        initCore.decollateralizeWLp(alicePosId, address(mockWLpUniV2), 1, amt, ALICE);
        vm.stopPrank();
        assertEq(positionManager.getCollWLpAmt(alicePosId, address(mockWLpUniV2), 2), 0, 'wlp amt1');
        assertEq(positionManager.getCollWLpAmt(bobPosId, address(mockWLpUniV2), 1), 0, 'wlp amt2');
        assertEq(positionManager.getCollWLpAmt(alicePosId, address(mockWLpUniV2), 1), 0, 'wlp amt3');
        assertEq(IERC20(lp).balanceOf(ALICE), amt, 'lp amt');
        (,, address[] memory wLps, uint[][] memory ids, uint[][] memory wLpAmts) =
            positionManager.getPosCollInfo(alicePosId);
        assertEq(wLps.length, 0);
        assertEq(ids.length, 0);
        assertEq(wLpAmts.length, 0);
    }

    function testLiquidateWLpAllDebt() public {
        uint amt = 1e15;
        uint posId = _openPositionWithLp(ALICE, amt);
        _addRewards(1);
        console.log(positionManager.getCollWLpAmt(posId, address(mockWLpUniV2), 1));
        vm.startPrank(ALICE, ALICE);
        initCore.borrow(address(lendingPools[WETH]), 1e18, posId, ALICE);
        vm.stopPrank();
        // set new factor to liquidate
        vm.startPrank(ADMIN, ADMIN);
        address[] memory tokens = new address[](1);
        tokens[0] = lp;
        uint128[] memory factors = new uint128[](1);
        factors[0] = 4e15;
        config.setCollFactors_e18(3, tokens, factors);
        vm.stopPrank();
        address pool = address(lendingPools[WETH]);
        // liquidate
        deal(WETH, BOB, 1e18);
        vm.startPrank(BOB, BOB);
        IERC20(WETH).approve(address(initCore), type(uint).max);
        console.log(initCore.getPosHealthCurrent_e18(posId));
        uint lpOut = initCore.liquidateWLp(
            posId, pool, positionManager.getPosDebtShares(posId, pool), address(mockWLpUniV2), 1, 0
        );
        vm.stopPrank();
        assertEq(IERC20(lp).balanceOf(BOB), lpOut);
        assertEq(positionManager.getCollWLpAmt(posId, address(mockWLpUniV2), 1), amt - lpOut);
        assertEq(initCore.getPosHealthCurrent_e18(posId), type(uint).max);
        tokens = mockWLpUniV2.rewardTokens(1);
        uint[] memory pendingRewards = new uint[](tokens.length);
        uint[] memory balBfs = new uint[](tokens.length);
        for (uint i; i < tokens.length; i++) {
            pendingRewards[i] = positionManager.pendingRewards(posId, tokens[i]);
            balBfs[i] = IERC20(tokens[i]).balanceOf(ALICE);
            assertGt(pendingRewards[i], 0);
        }
        vm.startPrank(ALICE, ALICE);
        positionManager.claimPendingRewards(posId, tokens, ALICE);
        vm.stopPrank();
        for (uint i; i < tokens.length; i++) {
            assertEq(IERC20(tokens[i]).balanceOf(ALICE), balBfs[i] + pendingRewards[i]);
            assertEq(positionManager.pendingRewards(posId, tokens[i]), 0);
        }
    }

    function testLiquidateWLpSimple() public {
        uint amt = 1e15;
        uint posId = _openPositionWithLp(ALICE, amt);
        _addRewards(1);
        console.log(positionManager.getCollWLpAmt(posId, address(mockWLpUniV2), 1));
        vm.startPrank(ALICE, ALICE);
        initCore.borrow(address(lendingPools[WETH]), 1e18, posId, ALICE);
        vm.stopPrank();
        // set new factor to liquidate
        vm.startPrank(ADMIN, ADMIN);
        address[] memory tokens = new address[](1);
        tokens[0] = lp;
        uint128[] memory factors = new uint128[](1);
        factors[0] = 1;
        config.setCollFactors_e18(3, tokens, factors);
        vm.stopPrank();
        address pool = address(lendingPools[WETH]);
        // liquidate
        deal(WETH, BOB, 1e18);
        vm.startPrank(BOB, BOB);
        IERC20(WETH).approve(address(initCore), type(uint).max);
        uint lpOut = initCore.liquidateWLp(
            posId, pool, positionManager.getPosDebtShares(posId, pool) / 500, address(mockWLpUniV2), 1, 0
        );
        vm.stopPrank();
        assertEq(IERC20(lp).balanceOf(BOB), lpOut);
        assertEq(positionManager.getCollWLpAmt(posId, address(mockWLpUniV2), 1), amt - lpOut);
        tokens = mockWLpUniV2.rewardTokens(1);
        uint[] memory pendingRewards = new uint[](tokens.length);
        uint[] memory balBfs = new uint[](tokens.length);
        for (uint i; i < tokens.length; i++) {
            pendingRewards[i] = positionManager.pendingRewards(posId, tokens[i]);
            balBfs[i] = IERC20(tokens[i]).balanceOf(ALICE);
            assertGt(pendingRewards[i], 0);
        }
        vm.startPrank(ALICE, ALICE);
        positionManager.claimPendingRewards(posId, tokens, ALICE);
        vm.stopPrank();
        for (uint i; i < tokens.length; i++) {
            uint balance = IERC20(tokens[i]).balanceOf(ALICE);
            assertEq(balance, balBfs[i] + pendingRewards[i]);
            balBfs[i] = balance;
            assertEq(positionManager.pendingRewards(posId, tokens[i]), 0);
        }
        _addRewards(1);
        vm.startPrank(ALICE, ALICE);
        positionManager.harvestTo(posId, address(mockWLpUniV2), 1, ALICE);
        vm.stopPrank();
        for (uint i; i < tokens.length; i++) {
            assertGt(IERC20(tokens[i]).balanceOf(ALICE), balBfs[i]);
        }
    }

    function testLiquidateThenOwnerClosePosition() public {
        uint amt = 1e15;
        uint posId = _openPositionWithLp(ALICE, amt);
        console.log(positionManager.getCollWLpAmt(posId, address(mockWLpUniV2), 1));
        vm.startPrank(ALICE, ALICE);
        initCore.borrow(address(lendingPools[WETH]), 1e18, posId, ALICE);
        vm.stopPrank();
        // set new factor to liquidate
        vm.startPrank(ADMIN, ADMIN);
        address[] memory tokens = new address[](1);
        tokens[0] = lp;
        uint128[] memory factors = new uint128[](1);
        factors[0] = 1;
        config.setCollFactors_e18(3, tokens, factors);
        vm.stopPrank();
        address pool = address(lendingPools[WETH]);
        // liquidate
        deal(WETH, BOB, 1e18);
        vm.startPrank(BOB, BOB);
        IERC20(WETH).approve(address(initCore), type(uint).max);
        initCore.liquidateWLp(posId, pool, positionManager.getPosDebtShares(posId, pool), address(mockWLpUniV2), 1, 0);
        vm.stopPrank();
        uint collCredit_e36Bf = initCore.getCollateralCreditCurrent_e36(posId);
        vm.startPrank(ALICE, ALICE);
        deal(WETH, ALICE, 1e18);
        IERC20(WETH).transfer(address(lendingPools[WETH]), 1e18);
        initCore.mintTo(address(lendingPools[WETH]), address(positionManager));
        initCore.collateralize(posId, address(lendingPools[WETH]));
        assertGt(initCore.getCollateralCreditCurrent_e36(posId), collCredit_e36Bf, 'weth not credited');
        initCore.decollateralizeWLp(
            posId, address(mockWLpUniV2), 1, positionManager.getCollWLpAmt(posId, address(mockWLpUniV2), 1), ALICE
        );
        vm.stopPrank();
    }

    function testSetPosMode() public {
        uint posId = _openPositionWithLp(ALICE, 100000000);
        vm.startPrank(ALICE, ALICE);
        // change to not supported mode
        vm.expectRevert(bytes('#500'));
        initCore.setPosMode(posId, 1);
        // remove all lp
        initCore.decollateralizeWLp(
            posId, address(mockWLpUniV2), 1, positionManager.getCollWLpAmt(posId, address(mockWLpUniV2), 1), ALICE
        );
        initCore.setPosMode(posId, 1);
        vm.stopPrank();
        assertEq(positionManager.getPosMode(posId), 1);
    }
}
