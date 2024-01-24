pragma solidity ^0.8.0;

import '../helper/DeployAll.sol';
import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

contract TestConfig is DeployAll {
    function testSetModeConfig() public {
        vm.startPrank(ADMIN);
        address[] memory mode100CollPools = new address[](3);
        mode100CollPools[0] = address(lendingPools[USDT]);
        mode100CollPools[1] = address(lendingPools[WETH]);
        mode100CollPools[2] = address(lendingPools[WBTC]);
        uint128[] memory mode100CollFactors = new uint128[](3);
        mode100CollFactors[0] = 952e15; // USDT: 0.952
        mode100CollFactors[1] = 909e15; // WETH 0.909
        mode100CollFactors[2] = 909e15; // WBTC 0.909
        address[] memory mode100BorrPools = new address[](2);
        mode100BorrPools[0] = address(lendingPools[WETH]);
        mode100BorrPools[1] = address(lendingPools[WBTC]);
        uint128[] memory mode100BorrFactors = new uint128[](2);
        mode100BorrFactors[0] = 11e17; // WETH: 1.1
        mode100BorrFactors[1] = 11e17; // WBTC: 1.1
        config.setCollFactors_e18(100, mode100CollPools, mode100CollFactors);
        config.setBorrFactors_e18(100, mode100BorrPools, mode100BorrFactors);
        uint64 maxHealthAfterLiq = 1.1e18;
        config.setMaxHealthAfterLiq_e18(100, maxHealthAfterLiq);
        vm.stopPrank();

        (address[] memory collPools, address[] memory borrPools, uint maxHealthAfterLiq_e18, uint8 maxCollWLpCount) =
            config.getModeConfig(100);

        assertEq(maxHealthAfterLiq, maxHealthAfterLiq_e18);
        for (uint i; i < collPools.length; ++i) {
            assertEq(collPools[i], mode100CollPools[i]);
        }
        for (uint i; i < borrPools.length; ++i) {
            assertEq(borrPools[i], mode100BorrPools[i]);
        }
    }
}
