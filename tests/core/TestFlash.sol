pragma solidity ^0.8.19;

import '../helper/DeployAll.sol';
import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';
import {ILendingPool} from '../../contracts/interfaces/lending_pool/ILendingPool.sol';
import {IInitCore} from '../../contracts/interfaces/core/IInitCore.sol';
import {IFlashReceiver} from '../../contracts/interfaces/receiver/IFlashReceiver.sol';

contract FlashReceiver is IFlashReceiver {
    IInitCore public immutable initCore;

    constructor(address _initCore) {
        initCore = IInitCore(_initCore);
    }

    function flashCallback(address[] calldata _pools, uint[] calldata _amts, bytes calldata) public {
        for (uint i = 0; i < _pools.length; i++) {
            address token = ILendingPool(_pools[i]).underlyingToken();
            IERC20(token).transfer(_pools[i], _amts[i]);
        }
    }

    function flash(address[] calldata _pools, uint[] calldata _amts, bytes calldata _data) external {
        initCore.flash(_pools, _amts, _data);
    }
}

contract FlashReceiverMint is IFlashReceiver {
    IInitCore public immutable initCore;

    constructor(address _initCore) {
        initCore = IInitCore(_initCore);
    }

    function flashCallback(address[] calldata _pools, uint[] calldata _amts, bytes calldata) public {
        for (uint i = 0; i < _pools.length;) {
            address token = ILendingPool(_pools[i]).underlyingToken();
            IERC20(token).transfer(_pools[i], _amts[i]);
            initCore.mintTo(_pools[i], address(this));
            revert('this function should revert');
        }
    }

    function flash(address[] calldata _pools, uint[] calldata _amts, bytes calldata _data) external {
        initCore.flash(_pools, _amts, _data);
    }
}

contract FlashReceiverNoRepay is IFlashReceiver {
    IInitCore public immutable initCore;

    constructor(address _initCore) {
        initCore = IInitCore(_initCore);
    }

    function flashCallback(address[] calldata, uint[] calldata, bytes calldata) public {}

    function flash(address[] calldata _pools, uint[] calldata _amts, bytes calldata _data) external {
        initCore.flash(_pools, _amts, _data);
    }
}

contract TestFlash is DeployAll {
    FlashReceiverMint public flashReceiverMint;
    FlashReceiverNoRepay public flashReceiverNoRepay;
    FlashReceiver public flashReceiver;

    function setUp() public override {
        super.setUp();
        _setUpLiquidity();
        flashReceiverMint = new FlashReceiverMint(address(initCore));
        flashReceiverNoRepay = new FlashReceiverNoRepay(address(initCore));
        flashReceiver = new FlashReceiver(address(initCore));
    }

    function testFlashDuplicatePools() public {
        address[] memory pools = new address[](3);
        uint[] memory amts = new uint[](3);
        bytes memory data;
        pools[0] = address(lendingPools[USDT]);
        pools[1] = address(lendingPools[WETH]);
        pools[2] = address(lendingPools[WETH]);
        vm.expectRevert(bytes('#306'));
        initCore.flash(pools, amts, data);
    }

    function testFlashReentrancy() public {
        address[] memory pools = new address[](2);
        uint[] memory amts = new uint[](2);
        bytes memory data;
        pools[0] = address(lendingPools[USDT]);
        pools[1] = address(lendingPools[WETH]);
        amts[0] = 1e10;
        amts[1] = 1e18;
        vm.expectRevert('ReentrancyGuard: reentrant call');
        flashReceiverMint.flash(pools, amts, data);
    }

    function testFlashNotRepay() public {
        address[] memory pools = new address[](2);
        uint[] memory amts = new uint[](2);
        bytes memory data;
        pools[0] = address(lendingPools[USDT]);
        pools[1] = address(lendingPools[WETH]);
        amts[0] = 1e10;
        amts[1] = 1e18;
        vm.expectRevert(bytes('#405'));
        flashReceiverNoRepay.flash(pools, amts, data);
    }

    function testFlash() public {
        address[] memory pools = new address[](2);
        uint[] memory amts = new uint[](2);
        uint[] memory cashes = new uint[](2);
        bytes memory data;
        pools[0] = address(lendingPools[USDT]);
        pools[1] = address(lendingPools[WETH]);
        amts[0] = 1e10;
        amts[1] = 1e18;
        cashes[0] = IERC20(USDT).balanceOf(pools[0]);
        cashes[1] = IERC20(WETH).balanceOf(pools[1]);
        deal(USDT, address(flashReceiver), amts[0] * 2);
        deal(WETH, address(flashReceiver), amts[1] * 2);
        flashReceiver.flash(pools, amts, data);
        assertGe(IERC20(USDT).balanceOf(pools[0]), cashes[0]);
        assertGe(IERC20(WETH).balanceOf(pools[1]), cashes[1]);
    }
}
