// test multicall with bad health (expect revert)
// test multicall with good health and bad health (expect revert)
// test multicall with flash (expect revert)

pragma solidity ^0.8.0;

import '../helper/DeployAll.sol';
import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

contract TestMulticall is DeployAll {
    function setUp() public override {
        super.setUp();
        _setUpLiquidity();
    }

    function testMulticallBadHealth() public {
        vm.startPrank(ALICE, ALICE);
        uint posId = initCore.createPos(1, address(0));
        bytes[] memory multicallData = new bytes[](2);
        multicallData[0] =
            abi.encodeWithSelector(initCore.borrow.selector, address(lendingPools[WETH]), 1e18, posId, address(this));
        multicallData[1] =
            abi.encodeWithSelector(initCore.borrow.selector, address(lendingPools[USDT]), 1e10, posId, address(this));
        vm.expectRevert(bytes('#300'));
        initCore.multicall(multicallData);
        vm.stopPrank();
    }

    function testMulticallGoodHealthWithBadHealth() public {
        vm.startPrank(ALICE, ALICE);
        uint posId1 = initCore.createPos(1, address(0));
        uint posId2 = initCore.createPos(1, address(0));
        deal(USDT, ALICE, 1e10);
        IERC20(USDT).transfer(address(lendingPools[USDT]), 1e10);
        bytes[] memory multicallData = new bytes[](4);
        multicallData[0] =
            abi.encodeWithSelector(initCore.borrow.selector, address(lendingPools[WETH]), 1e18, posId1, address(this));
        multicallData[1] = abi.encodeWithSelector(
            initCore.borrow.selector, address(lendingPools[USDT]), 1e10, posId2, address(lendingPools[USDT])
        );
        multicallData[2] =
            abi.encodeWithSelector(initCore.mintTo.selector, address(lendingPools[USDT]), address(positionManager));
        multicallData[3] = abi.encodeWithSelector(initCore.collateralize.selector, posId1, address(lendingPools[USDT]));
        vm.expectRevert(bytes('#300'));
        initCore.multicall(multicallData);
        vm.stopPrank();
    }

    function testChangeCollateral() public {
        vm.startPrank(ALICE, ALICE);
        uint posId = initCore.createPos(1, address(0));
        bytes[] memory multicallData = new bytes[](3);
        deal(USDT, ALICE, 1e10);
        IERC20(USDT).transfer(address(lendingPools[USDT]), 1e10);
        multicallData[0] =
            abi.encodeWithSelector(initCore.borrow.selector, address(lendingPools[WETH]), 1e18, posId, address(this));
        multicallData[1] =
            abi.encodeWithSelector(initCore.mintTo.selector, address(lendingPools[USDT]), address(positionManager));
        multicallData[2] = abi.encodeWithSelector(initCore.collateralize.selector, posId, address(lendingPools[USDT]));
        initCore.multicall(multicallData);
        deal(WBTC, ALICE, 1e8);
        IERC20(WBTC).transfer(address(lendingPools[WBTC]), 1e8);
        multicallData[0] = abi.encodeWithSelector(
            initCore.decollateralize.selector,
            posId,
            address(lendingPools[USDT]),
            positionManager.getCollAmt(posId, address(lendingPools[USDT])),
            address(this)
        );
        multicallData[1] =
            abi.encodeWithSelector(initCore.mintTo.selector, address(lendingPools[WBTC]), address(positionManager));
        multicallData[2] = abi.encodeWithSelector(initCore.collateralize.selector, posId, address(lendingPools[WBTC]));
        initCore.multicall(multicallData);
        vm.stopPrank();
    }

    function testChangeDebt() public {
        vm.startPrank(ALICE, ALICE);
        uint posId = initCore.createPos(1, address(0));
        bytes[] memory multicallData = new bytes[](3);
        deal(USDT, ALICE, 1e10);
        IERC20(USDT).transfer(address(lendingPools[USDT]), 1e10);
        multicallData[0] =
            abi.encodeWithSelector(initCore.borrow.selector, address(lendingPools[WETH]), 1e18, posId, address(this));
        multicallData[1] =
            abi.encodeWithSelector(initCore.mintTo.selector, address(lendingPools[USDT]), address(positionManager));
        multicallData[2] = abi.encodeWithSelector(initCore.collateralize.selector, posId, address(lendingPools[USDT]));
        initCore.multicall(multicallData);
        deal(WETH, ALICE, 1e19);
        IERC20(WETH).approve(address(initCore), 2 ** 256 - 1);
        multicallData = new bytes[](2);
        multicallData[0] =
            abi.encodeWithSelector(initCore.borrow.selector, address(lendingPools[WMNT]), 1e18, posId, address(this));
        multicallData[1] = abi.encodeWithSelector(
            initCore.repay.selector,
            address(lendingPools[WETH]),
            positionManager.getPosDebtShares(posId, address(lendingPools[WETH])),
            posId
        );
        initCore.multicall(multicallData);
        vm.stopPrank();
    }

    function testMulticallFlash() public {
        bytes[] memory multicallData = new bytes[](1);
        address[] memory pools;
        uint[] memory amts;
        bytes memory data;
        multicallData[0] = abi.encodeWithSelector(initCore.flash.selector, pools, amts, data);
        vm.expectRevert(bytes('#302'));
        initCore.multicall(multicallData);
    }
}
