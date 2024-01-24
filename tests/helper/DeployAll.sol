// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';

import {IERC20Metadata} from '@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {DeployBase} from './DeployBase.sol';

contract DeployAll is DeployBase, Test {
    // RPCs
    string private constant MANTLE_RPC_URL = 'https://rpc.mantle.xyz';
    string private constant LOCAL_RPC_URL = 'http://localhost:8545';
    uint private mantleFork;
    uint private localFork;

    function setUp() public virtual {
        mantleFork = vm.createFork(MANTLE_RPC_URL);
        vm.selectFork(mantleFork);
        // To speed up the test time on development, spin a local fork using "anvil -f https://rpc.mantle.xyz"
        // localFork = vm.createFork(LOCAL_RPC_URL);
        // vm.selectFork(localFork);
        startHoax(ADMIN);
        _deploy();
        _setConfigs();
        vm.stopPrank();
    }

    function _setUpLiquidity() internal {
        // provide liquidity to lending pools
        for (uint i = 0; i < poolConfigs.length; ++i) {
            // NOTE: ignore USDY pool for now
            if (poolConfigs[i].underlyingToken == USDY) continue;
            address lendingPool = address(lendingPools[poolConfigs[i].underlyingToken]);
            IERC20Metadata underlyingToken = IERC20Metadata(poolConfigs[i].underlyingToken);
            // init liquidity 1m$ to each pool
            uint amount = _priceToTokenAmt(poolConfigs[i].underlyingToken, 1_000_000);
            deal(poolConfigs[i].underlyingToken, address(this), amount);
            underlyingToken.transfer(lendingPool, amount);
            initCore.mintTo(lendingPool, address(1));
        }
    }

    function _priceToTokenAmt(address token, uint usd) internal view returns (uint tokenAmt) {
        // get price from init oracle
        // convert usd to token amount
        tokenAmt = (usd * 1e36) / initOracle.getPrice_e36(token);
    }
}
