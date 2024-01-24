pragma solidity ^0.8.19;

import '../helper/DeployAll.sol';
import '@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';
import {IMoePair} from '../../contracts/interfaces/wrapper/moe/IMoePair.sol';
import {IMasterChef} from '../../contracts/interfaces/wrapper/moe/IMasterChef.sol';
import {ModeStatus} from '../../contracts/interfaces/core/IConfig.sol';

interface IUniPair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves() external view returns (uint112, uint112, uint32);

    function mint(address to) external returns (uint);
}

contract TestWLpMoeMasterChef is DeployAll {
    using Math for uint;

    address lp = WETH_USDC_MOE;
    uint lpPid = 2;
    address topHolder = 0x18f7238119a99443e2b7C17727Dfe8c360492c91;
    uint constant ONE_E18 = 1e18;

    function setUp() public override {
        super.setUp();
        _setUpLiquidity();
        _setUpWLp();
    }

    function _setUpWLp() internal {
        address[] memory wLps = new address[](1);
        wLps[0] = address(wLpMoeMasterChef);
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
        address token0 = IMoePair(lp).token0();
        address token1 = IMoePair(lp).token1();
        uint amt0 = _priceToTokenAmt(token0, _usd);
        uint amt1 = _priceToTokenAmt(token1, _usd);
        deal(token0, _to, amt0);
        deal(token1, _to, amt1);
        vm.startPrank(_to, _to);
        IERC20(token0).transfer(lp, amt0);
        IERC20(token1).transfer(lp, amt1);
        IMoePair(lp).mint(_to);
        vm.stopPrank();
    }

    function _depositLp(address _user, uint _amt, uint _posId) internal {
        // deal lp
        _dealLp(_user, _amt);
        vm.startPrank(_user, _user);
        IERC20(lp).approve(address(initCore), type(uint).max);

        uint collCreditBefore = initCore.getCollateralCreditCurrent_e36(_posId);

        // multicall via core to deposit lp
        bytes[] memory data = new bytes[](3);
        uint tokenId = wLpMoeMasterChef.lastId() + 1;
        data[0] = abi.encodeWithSelector(initCore.transferToken.selector, lp, address(wrapCenter), _amt);
        data[1] = abi.encodeWithSelector(
            initCore.callback.selector,
            address(wrapCenter),
            0,
            abi.encodeWithSelector(
                wrapCenter.wrapLp.selector, address(wLpMoeMasterChef), lp, address(positionManager), abi.encode(lpPid)
            )
        );
        data[2] = abi.encodeWithSelector(initCore.collateralizeWLp.selector, _posId, address(wLpMoeMasterChef), tokenId);

        initCore.multicall(data);

        // check position hold wlp
        assertEq(positionManager.getCollWLpAmt(_posId, address(wLpMoeMasterChef), tokenId), _amt);
        (,, address[] memory wLps, uint[][] memory ids, uint[][] memory wLpAmts) =
            positionManager.getPosCollInfo(_posId);
        assertEq(wLps.length, 1);
        assertEq(wLps[0], address(wLpMoeMasterChef));
        assertEq(ids[0].length, 1);
        assertEq(ids[0][0], tokenId);
        assertEq(wLpAmts[0].length, 1);
        assertEq(wLpAmts[0][0], _amt);

        // check collcredit
        uint collCreditAfter = initCore.getCollateralCreditCurrent_e36(_posId);
        console.log('CollateralCreditBefore: ', collCreditBefore);
        console.log('CollateralCreditAfter: ', collCreditAfter);
        assertGt(collCreditAfter, collCreditBefore);
        vm.stopPrank();
    }

    function _openPositionWithLp(address _user, uint _amt) internal returns (uint posId) {
        vm.startPrank(_user, _user);
        posId = initCore.createPos(3, ALICE);
        vm.stopPrank();
        _depositLp(_user, _amt, posId);
    }

    function _borrow(address _pool, uint _amt, uint _posId, address _from, address _to) internal {
        vm.startPrank(_from, _from);
        uint borrCreditBefore = initCore.getBorrowCreditCurrent_e36(_posId);
        initCore.borrow(_pool, _amt, _posId, _to);
        uint borrCreditAfter = initCore.getBorrowCreditCurrent_e36(_posId);
        assertGt(borrCreditAfter, borrCreditBefore);
        vm.stopPrank();
    }

    function _checkPositionIsHealthy(uint _posId) internal {
        uint posHealth_e18 = initCore.getPosHealthCurrent_e18(_posId);
        console.log('Position Health: ', posHealth_e18);
        assertGe(posHealth_e18, 1e18);
    }

    function testOraclePrice() public {
        _openPositionWithLp(ALICE, 100000000);
        uint price = wLpMoeMasterChef.calculatePrice_e36(1, address(initOracle));
        uint totalSupply = IERC20(lp).totalSupply();
        (uint112 r0, uint112 r1,) = IMoePair(lp).getReserves();
        uint priceSpot = (r0 * initOracle.getPrice_e36(IMoePair(lp).token0())) / totalSupply;
        priceSpot += (r1 * initOracle.getPrice_e36(IMoePair(lp).token1())) / totalSupply;

        assertApproxEqRel(price, priceSpot, 0.01e16); // 0.01% delta (100e16 is 100%)

        console.log(price, 'price wlp');
        console.log(priceSpot, 'price spot');
    }

    function testDepositSimple() public {
        _openPositionWithLp(ALICE, 100000000);
    }

    function testDepositAndBorrow() public {
        uint posId = _openPositionWithLp(ALICE, 100000000);
        // borrow
        _borrow(address(lendingPools[WETH]), 1, posId, ALICE, ALICE);

        // check health
        uint posHealth_e18 = initCore.getPosHealthCurrent_e18(posId);
        console.log('PosHealth: ', posHealth_e18);
        assertGe(posHealth_e18, 1e18);
    }

    function testDepositExcessMaxCollCount() public {
        uint posId = _openPositionWithLp(ALICE, 100000000);
        _addLp(ALICE, 1_000_000);
        uint totalLp = IERC20(lp).balanceOf(ALICE);
        vm.startPrank(ALICE, ALICE);
        IERC20(lp).approve(address(wLpMoeMasterChef), type(uint).max);
        for (uint i; i < MAX_COLL_COUNT; i++) {
            uint wLpId = wLpMoeMasterChef.wrap(lp, totalLp / MAX_COLL_COUNT, ALICE, abi.encode(lpPid));
            wLpMoeMasterChef.safeTransferFrom(ALICE, address(positionManager), wLpId);
            if (i == MAX_COLL_COUNT - 1) {
                vm.expectRevert(bytes('#602'));
            }
            initCore.collateralizeWLp(posId, address(wLpMoeMasterChef), wLpId);
        }
        vm.stopPrank();
    }

    function testTwoUserDepositLp() public {
        uint amt = 100000000;
        uint alicePosId = _openPositionWithLp(ALICE, amt); // tokenId is 1
        uint bobPosId = _openPositionWithLp(BOB, amt); // tokenId is 2
        assertEq(positionManager.getCollWLpAmt(alicePosId, address(wLpMoeMasterChef), 2), 0);
        assertEq(positionManager.getCollWLpAmt(bobPosId, address(wLpMoeMasterChef), 1), 0);
        assertEq(initCore.getCollateralCreditCurrent_e36(alicePosId), initCore.getCollateralCreditCurrent_e36(bobPosId));
    }

    function testTwoUserDepositLpDuplicatedId() public {
        uint amt = 100000000;
        _openPositionWithLp(ALICE, amt); // wLp tokenId is 1
        vm.startPrank(BOB, BOB);
        uint bobPosId = initCore.createPos(3, BOB);
        // bob try deposit alice's lp
        vm.expectRevert(bytes('#604'));
        initCore.collateralizeWLp(bobPosId, address(wLpMoeMasterChef), 1);
        vm.stopPrank();
    }

    function testCollateralizeFakeLp() public {
        uint amt = 100000000;
        _dealLp(ALICE, amt);
        vm.startPrank(ALICE, ALICE);
        IERC20(lp).approve(address(wLpMoeMasterChef), type(uint).max);
        uint alicePosId = initCore.createPos(3, ALICE);
        // 1. fake id (not wrapped yet)
        vm.expectRevert(bytes('#500'));
        initCore.collateralizeWLp(alicePosId, address(wLpMoeMasterChef), 1);
        // 2. fake wlp address
        vm.expectRevert(bytes('#501'));
        initCore.collateralizeWLp(alicePosId, address(this), 1);
        // 3. not transfer wlp to position manager
        uint wLpId = wLpMoeMasterChef.wrap(lp, amt, ALICE, abi.encode(lpPid));
        vm.expectRevert(bytes('#104'));
        initCore.collateralizeWLp(alicePosId, address(wLpMoeMasterChef), wLpId);
        vm.stopPrank();
    }

    function testTwoUserDepositLpThenAliceWithdraw() public {
        uint amt = 100000000;
        uint withdrawAmt = amt / 2;
        // deposits
        uint alicePosId = _openPositionWithLp(ALICE, amt); // tokenId 1
        uint bobPosId = _openPositionWithLp(BOB, amt); // tokenId 2
        // alice withdraw
        vm.startPrank(ALICE, ALICE);
        initCore.decollateralizeWLp(alicePosId, address(wLpMoeMasterChef), 1, withdrawAmt, ALICE);
        vm.stopPrank();

        assertEq(positionManager.getCollWLpAmt(alicePosId, address(wLpMoeMasterChef), 2), 0);
        assertEq(positionManager.getCollWLpAmt(bobPosId, address(wLpMoeMasterChef), 1), 0);
        assertEq(positionManager.getCollWLpAmt(alicePosId, address(wLpMoeMasterChef), 1), amt - withdrawAmt);
        assertEq(IERC20(lp).balanceOf(ALICE), withdrawAmt);

        // check health
        _checkPositionIsHealthy(alicePosId);
        _checkPositionIsHealthy(bobPosId);
    }

    function testTwoUserDepositLpThenAliceWithdrawAll() public {
        uint amt = 100000000;
        uint alicePosId = _openPositionWithLp(ALICE, amt);
        uint bobPosId = _openPositionWithLp(BOB, amt);
        vm.startPrank(ALICE, ALICE);
        initCore.decollateralizeWLp(alicePosId, address(wLpMoeMasterChef), 1, amt, ALICE);
        vm.stopPrank();
        assertEq(positionManager.getCollWLpAmt(alicePosId, address(wLpMoeMasterChef), 2), 0, 'wlp amt1');
        assertEq(positionManager.getCollWLpAmt(bobPosId, address(wLpMoeMasterChef), 1), 0, 'wlp amt2');
        assertEq(positionManager.getCollWLpAmt(alicePosId, address(wLpMoeMasterChef), 1), 0, 'wlp amt3');
        assertEq(IERC20(lp).balanceOf(ALICE), amt, 'lp amt');

        // collInfo removed
        (,, address[] memory wLps, uint[][] memory ids, uint[][] memory wLpAmts) =
            positionManager.getPosCollInfo(alicePosId);
        assertEq(wLps.length, 0);
        assertEq(ids.length, 0);
        assertEq(wLpAmts.length, 0);

        // check health
        _checkPositionIsHealthy(alicePosId);
        _checkPositionIsHealthy(bobPosId);
    }

    function testLiquidateWLpAllDebt() public {
        uint amt = 1e15;
        uint posId = _openPositionWithLp(ALICE, amt);

        // time forwards, wLp rewards should grow
        vm.warp(block.timestamp + 2 days);

        console.log('WLp Collateral Amounts', positionManager.getCollWLpAmt(posId, address(wLpMoeMasterChef), 1));

        _borrow(address(lendingPools[WETH]), 1e18, posId, ALICE, ALICE);

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
        console.log('Position Health', initCore.getPosHealthCurrent_e18(posId));
        uint lpOut = initCore.liquidateWLp(
            posId, pool, positionManager.getPosDebtShares(posId, pool), address(wLpMoeMasterChef), 1, 0
        );
        vm.stopPrank();
        assertEq(IERC20(lp).balanceOf(BOB), lpOut);
        assertEq(positionManager.getCollWLpAmt(posId, address(wLpMoeMasterChef), 1), amt - lpOut);
        assertEq(initCore.getPosHealthCurrent_e18(posId), type(uint).max);

        tokens = wLpMoeMasterChef.rewardTokens(1);
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
            console.log('Reward Token: ', tokens[i]);
            console.log('Pending Reward: ', pendingRewards[i]);
            assertEq(IERC20(tokens[i]).balanceOf(ALICE), balBfs[i] + pendingRewards[i]);
            assertEq(positionManager.pendingRewards(posId, tokens[i]), 0);
        }

        // check position health
        _checkPositionIsHealthy(posId);
    }

    function testLiquidateWLpSimple() public {
        uint amt = 1e15;
        uint posId = _openPositionWithLp(ALICE, amt);

        // time forwards, wLp rewards should grow
        vm.warp(block.timestamp + 2 days);

        console.log('WLp Collateral Amounts', positionManager.getCollWLpAmt(posId, address(wLpMoeMasterChef), 1));

        // borrow
        _borrow(address(lendingPools[WETH]), 1e18, posId, ALICE, ALICE);

        _checkPositionIsHealthy(posId);
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
            posId, pool, positionManager.getPosDebtShares(posId, pool) - 1, address(wLpMoeMasterChef), 1, 0
        );

        vm.stopPrank();
        assertEq(IERC20(lp).balanceOf(BOB), lpOut);
        assertEq(positionManager.getCollWLpAmt(posId, address(wLpMoeMasterChef), 1), amt - lpOut);
        tokens = wLpMoeMasterChef.rewardTokens(1);
        uint[] memory pendingRewards = new uint[](tokens.length);
        uint[] memory balBfs = new uint[](tokens.length);
        for (uint i; i < tokens.length; i++) {
            pendingRewards[i] = positionManager.pendingRewards(posId, tokens[i]);
            balBfs[i] = IERC20(tokens[i]).balanceOf(ALICE);
            assertGt(pendingRewards[i], 0);
        }

        // claim pending rewards
        vm.startPrank(ALICE, ALICE);
        positionManager.claimPendingRewards(posId, tokens, ALICE);

        for (uint i; i < tokens.length; i++) {
            uint balance = IERC20(tokens[i]).balanceOf(ALICE);
            assertEq(balance, balBfs[i] + pendingRewards[i]);
            assertEq(positionManager.pendingRewards(posId, tokens[i]), 0);
            balBfs[i] = balance;
        }

        _checkPositionIsHealthy(posId);

        // time forwards, wLp rewards should grow
        vm.warp(block.timestamp + 1 days);

        // directly harvest rewards to the user
        positionManager.harvestTo(posId, address(wLpMoeMasterChef), 1, ALICE);
        vm.stopPrank();
        for (uint i; i < tokens.length; i++) {
            assertGt(IERC20(tokens[i]).balanceOf(ALICE), balBfs[i]);
        }

        // check position health (should be reduce because of the debt growth)
        _checkPositionIsHealthy(posId);
    }

    function testLiquidateThenOwnerClosePosition() public {
        uint amt = 1e15;
        uint posId = _openPositionWithLp(ALICE, amt);
        console.log(positionManager.getCollWLpAmt(posId, address(wLpMoeMasterChef), 1));

        // borrow
        _borrow(address(lendingPools[WETH]), 1e18, posId, ALICE, ALICE);

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
        initCore.liquidateWLp(
            posId, pool, positionManager.getPosDebtShares(posId, pool), address(wLpMoeMasterChef), 1, 0
        );
        vm.stopPrank();
        uint collCredit_e36Bf = initCore.getCollateralCreditCurrent_e36(posId);
        vm.startPrank(ALICE, ALICE);
        deal(WETH, ALICE, 1e18);
        IERC20(WETH).transfer(address(lendingPools[WETH]), 1e18);
        initCore.mintTo(address(lendingPools[WETH]), address(positionManager));
        initCore.collateralize(posId, address(lendingPools[WETH]));
        assertGt(initCore.getCollateralCreditCurrent_e36(posId), collCredit_e36Bf, 'weth not credited');
        initCore.decollateralizeWLp(
            posId,
            address(wLpMoeMasterChef),
            1,
            positionManager.getCollWLpAmt(posId, address(wLpMoeMasterChef), 1),
            ALICE
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
            posId,
            address(wLpMoeMasterChef),
            1,
            positionManager.getCollWLpAmt(posId, address(wLpMoeMasterChef), 1),
            ALICE
        );
        initCore.setPosMode(posId, 1);
        vm.stopPrank();
        assertEq(positionManager.getPosMode(posId), 1);
    }

    function testPendingRewards() public {
        uint posId = _openPositionWithLp(ALICE, 100000000);
        vm.startPrank(ALICE, ALICE);
        vm.warp(block.timestamp + 2 days);
        (address[] memory tokens, uint[] memory amts) = wLpMoeMasterChef.getPendingRewards(1);
        uint[] memory balanceBfs = new uint[](tokens.length);
        for (uint i; i < balanceBfs.length; i++) {
            balanceBfs[i] = IERC20(tokens[i]).balanceOf(ALICE);
        }

        // harvest
        positionManager.harvestTo(posId, address(wLpMoeMasterChef), 1, ALICE);

        uint[] memory balanceAfs = new uint[](tokens.length);
        for (uint i; i < balanceAfs.length; i++) {
            balanceAfs[i] = IERC20(tokens[i]).balanceOf(ALICE);
        }

        // check reward amts
        console2.log('=== Reward Tokens ===');
        for (uint i; i < tokens.length; i++) {
            console2.log('Reward Token: ', tokens[i]);
            console2.log('Pending Reward', amts[i]);
            console2.log('Harvested Reward', balanceAfs[i] - balanceBfs[i]);
            assertEq(amts[i], balanceAfs[i] - balanceBfs[i]);
        }
    }

    function testSetPosModeSetWhitelistedWLpToFalse() public {
        uint posId = _openPositionWithLp(ALICE, 100000000);
        vm.startPrank(ALICE, ALICE);
        // change to not supported mode
        vm.expectRevert(bytes('#500'));
        initCore.setPosMode(posId, 1);

        // set whitelisted Wlps to false
        address[] memory wLps = new address[](1);
        wLps[0] = address(wLpMoeMasterChef);
        vm.startPrank(ADMIN, ADMIN);
        config.setWhitelistedWLps(wLps, false);
        vm.stopPrank();

        // set pos mode
        vm.startPrank(ALICE, ALICE);
        vm.expectRevert(bytes('#501'));
        initCore.setPosMode(posId, 1);
        vm.stopPrank();
        assertEq(positionManager.getPosMode(posId), 3);
    }

    function testSetPosModeAbletoRepayDebt() public {
        uint posId = _openPositionWithLp(ALICE, 100000000);
        vm.startPrank(ALICE, ALICE);
        // change to not supported mode
        // vm.expectRevert('#500');
        // initCore.setPosMode(posId, 1);
        // uint16 mode = positionManager.getPosMode(posId);
        ModeStatus memory modeStatus = config.getModeStatus(1);
        console.log('mode status: ', modeStatus.canRepay);

        ModeStatus memory newModeStatus = ModeStatus(true, true, true, false);
        vm.startPrank(ADMIN, ADMIN);
        address[] memory colls = new address[](1);
        uint128[] memory factors_e18 = new uint128[](1);
        colls[0] = lp;
        factors_e18[0] = 0.9e18;

        config.setCollFactors_e18(4, colls, factors_e18);
        config.setModeStatus(4, newModeStatus);
        config.setMaxCollWLpCount(4, 5);
        vm.stopPrank();

        vm.startPrank(ALICE, ALICE);
        vm.expectRevert(bytes('#403'));
        initCore.setPosMode(posId, 4);
        vm.stopPrank();

        assertEq(positionManager.getPosMode(posId), 3);
    }
}
