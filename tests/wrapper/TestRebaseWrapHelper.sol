// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '../helper/DeployAll.sol';

import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

contract TestRebaseWrapHelper is DeployAll {
    // mUSD whale from https://explorer.mantle.xyz/token/0xab575258d37EaA5C8956EfABe71F4eE8F6397cF3/token-holders
    // USDY whale from https://explorer.mantle.xyz/token/0x5bE26527e817998A7206475496fDE1E68957c5A6/token-holders
    address private constant mUSD_WHALE = 0x9FceDEd3a0c838d1e73E88ddE466f197DF379f70;
    address private constant USDY_WHALE = 0x94FEC56BBEcEaCC71c9e61623ACE9F8e1B1cf473;

    function testWrapRebase() public {
        uint amount = 1 ether;
        (address yieldToken, address rebaseToken) = _validateTokens();
        address rebaseWrapHelperAddress = address(musdusdyWrapHelper);
        startHoax(mUSD_WHALE);
        IERC20(rebaseToken).approve(address(initCore), type(uint).max);
        _wrapRebase(rebaseToken, amount, ALICE, rebaseWrapHelperAddress);
        uint yieldTokenBalance = IERC20(yieldToken).balanceOf(ALICE);
        assertApproxEqRel(amount, yieldTokenBalance, 0.1e18);
    }

    function testNotWhitelistedRebaseToken() public {
        uint amount = 1 ether;
        (address yieldToken, address rebaseToken) = _validateTokens();
        address rebaseWrapHelperAddress = address(musdusdyWrapHelper);
        startHoax(mUSD_WHALE);
        IERC20(rebaseToken).approve(address(initCore), type(uint).max);
        _wrapRebase(rebaseToken, amount, ALICE, rebaseWrapHelperAddress);
    }

    function testUnwrapRebase() public {
        uint amount = 1 ether;
        (address yieldToken, address rebaseToken) = _validateTokens();
        address rebaseWrapHelperAddress = address(musdusdyWrapHelper);
        startHoax(USDY_WHALE);
        IERC20(yieldToken).approve(address(initCore), type(uint).max);
        _unwrapRebase(yieldToken, amount, ALICE, rebaseWrapHelperAddress);
        uint rebaseBalance = IERC20(rebaseToken).balanceOf(ALICE);
        assertApproxEqRel(amount, rebaseBalance, 0.1e18);
    }

    function _validateTokens() internal returns (address yieldToken, address rebaseToken) {
        yieldToken = musdusdyWrapHelper.YIELD_BEARING_TOKEN();
        rebaseToken = musdusdyWrapHelper.REBASE_TOKEN();
        assertEq(yieldToken, USDY);
        assertEq(rebaseToken, mUSD);
    }

    //@note: for wrap and unwrap rebase token using multicall
    function _wrapRebase(address _tokenIn, uint _amount, address _to, address _rebaseWrapHelperAddress) internal {
        bytes[] memory calls = new bytes[](2);
        // 1. transfer token to lending pool
        calls[0] = abi.encodeWithSelector(initCore.transferToken.selector, _tokenIn, _rebaseWrapHelperAddress, _amount);
        // 2. wrap/unwrap token via wrap center
        bytes memory _wrapData = abi.encodeWithSelector(wrapCenter.wrapRebase.selector, _rebaseWrapHelperAddress, _to);
        calls[1] = abi.encodeWithSelector(initCore.callback.selector, address(wrapCenter), 0, _wrapData);
        initCore.multicall(calls);
    }

    function _unwrapRebase(address _tokenIn, uint _amount, address _to, address _rebaseWrapHelperAddress) internal {
        bytes[] memory calls = new bytes[](2);
        // 1. transfer token to lending pool
        calls[0] = abi.encodeWithSelector(initCore.transferToken.selector, _tokenIn, _rebaseWrapHelperAddress, _amount);
        // 2. wrap/unwrap token via wrap center
        bytes memory _wrapData = abi.encodeWithSelector(wrapCenter.unwrapRebase.selector, _rebaseWrapHelperAddress, _to);
        calls[1] = abi.encodeWithSelector(initCore.callback.selector, address(wrapCenter), 0, _wrapData);
        initCore.multicall(calls);
    }
}
