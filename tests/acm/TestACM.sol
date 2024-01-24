// SPDX-License-Identifier: NONE
pragma solidity ^0.8.19;

import '../helper/DeployAll.sol';
import {ModeStatus} from '../../contracts/interfaces/core/IConfig.sol';

contract TestACM is DeployAll {
    function testLendingPoolACM() public {
        vm.startPrank(ALICE, ALICE);
        vm.expectRevert(bytes('#101'));
        lendingPools[WETH].mint(address(this));
        vm.expectRevert(bytes('#101'));
        lendingPools[WETH].burn(address(this));
        vm.expectRevert(bytes('#101'));
        lendingPools[WETH].borrow(address(this), 1e18);
        vm.expectRevert(bytes('#101'));
        lendingPools[WETH].repay(1e18);
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x8fbcb4375b910093bcf636b6b2f26b26eda2a29ef5a8ee7de44b5743c3bf9a28'
        );
        lendingPools[WETH].setIrm(address(0));
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x8fbcb4375b910093bcf636b6b2f26b26eda2a29ef5a8ee7de44b5743c3bf9a28'
        );
        lendingPools[WETH].setReserveFactor_e18(1e18);
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x1e46cebd6689d8c64011118478db0c61a89aa2646c860df401de476fbf378983'
        );
        lendingPools[WETH].setTreasury(address(0));
        vm.stopPrank();
    }

    function testPosManagerACM() public {
        vm.startPrank(BOB, BOB);
        uint posId = initCore.createPos(1, BOB);
        vm.stopPrank();
        vm.startPrank(ALICE, ALICE);
        vm.expectRevert(bytes('#307'));
        positionManager.setPosViewer(posId, ALICE);
        vm.expectRevert(bytes('#101'));
        positionManager.updatePosDebtShares(0, address(0), 1);
        vm.expectRevert(bytes('#101'));
        positionManager.updatePosMode(0, 1);
        vm.expectRevert(bytes('#101'));
        positionManager.addCollateral(0, address(0));
        vm.expectRevert(bytes('#101'));
        positionManager.addCollateralWLp(0, address(0), 0);
        vm.expectRevert(bytes('#101'));
        positionManager.removeCollateralTo(0, address(0), 1, address(0));
        vm.expectRevert(bytes('#101'));
        positionManager.removeCollateralWLpTo(0, address(0), 1, 0, address(0));
        vm.expectRevert(bytes('#101'));
        positionManager.createPos(address(0), 1, address(0));
        vm.expectRevert(bytes('#307'));
        positionManager.harvestTo(posId, address(0), 0, address(0));
        address[] memory tokens;
        vm.expectRevert(bytes('#307'));
        positionManager.claimPendingRewards(posId, tokens, address(0));
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x8fbcb4375b910093bcf636b6b2f26b26eda2a29ef5a8ee7de44b5743c3bf9a28'
        );
        positionManager.setMaxCollCount(0);
        vm.stopPrank();
    }

    function testInitCoreACM() public {
        vm.startPrank(BOB, BOB);
        uint posId = initCore.createPos(1, BOB);
        vm.stopPrank();
        vm.startPrank(ALICE, ALICE);
        vm.expectRevert(bytes('#307'));
        initCore.borrow(address(0), 1, posId, address(0));
        vm.expectRevert(bytes('#307'));
        initCore.repay(address(0), 1, posId);
        vm.expectRevert(bytes('#307'));
        initCore.setPosMode(posId, 1);
        vm.expectRevert(bytes('#307'));
        initCore.collateralize(posId, address(0));
        vm.expectRevert(bytes('#307'));
        initCore.decollateralize(posId, address(0), 1, address(0));
        vm.expectRevert(bytes('#307'));
        initCore.collateralizeWLp(posId, address(0), 0);
        vm.expectRevert(bytes('#307'));
        initCore.decollateralizeWLp(posId, address(0), 0, 1, address(0));
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x1e46cebd6689d8c64011118478db0c61a89aa2646c860df401de476fbf378983'
        );
        initCore.setConfig(address(0));
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x1e46cebd6689d8c64011118478db0c61a89aa2646c860df401de476fbf378983'
        );
        initCore.setOracle(address(0));
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x8fbcb4375b910093bcf636b6b2f26b26eda2a29ef5a8ee7de44b5743c3bf9a28'
        );
        initCore.setLiqIncentiveCalculator(address(0));
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x8fbcb4375b910093bcf636b6b2f26b26eda2a29ef5a8ee7de44b5743c3bf9a28'
        );
        initCore.setRiskManager(address(0));
        vm.stopPrank();
    }

    function testConfigACM() public {
        vm.startPrank(ALICE, ALICE);
        address[] memory tokens;
        uint128[] memory factors;
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x1e46cebd6689d8c64011118478db0c61a89aa2646c860df401de476fbf378983'
        );
        config.setCollFactors_e18(1, tokens, factors);
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x1e46cebd6689d8c64011118478db0c61a89aa2646c860df401de476fbf378983'
        );
        config.setBorrFactors_e18(1, tokens, factors);
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x8fbcb4375b910093bcf636b6b2f26b26eda2a29ef5a8ee7de44b5743c3bf9a28'
        );
        config.setModeStatus(0, ModeStatus(false, false, false, false));
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x8fbcb4375b910093bcf636b6b2f26b26eda2a29ef5a8ee7de44b5743c3bf9a28'
        );
        config.setMaxHealthAfterLiq_e18(1, 1e18);
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x1e46cebd6689d8c64011118478db0c61a89aa2646c860df401de476fbf378983'
        );
        config.setWhitelistedWLps(tokens, true);
        vm.stopPrank();
    }

    function testOracleACM() public {
        address[] memory tokens;
        address[] memory sources;
        uint[] memory deviations;
        vm.startPrank(ALICE, ALICE);
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x1e46cebd6689d8c64011118478db0c61a89aa2646c860df401de476fbf378983'
        );
        initOracle.setPrimarySources(tokens, sources);
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x1e46cebd6689d8c64011118478db0c61a89aa2646c860df401de476fbf378983'
        );
        initOracle.setSecondarySources(tokens, sources);
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x1e46cebd6689d8c64011118478db0c61a89aa2646c860df401de476fbf378983'
        );
        initOracle.setMaxPriceDeviations_e18(tokens, deviations);
        vm.stopPrank();
    }

    function testIncentiveACM() public {
        uint16[] memory modes;
        uint[] memory multipliers;
        address[] memory tokens;
        vm.startPrank(ALICE, ALICE);
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x1e46cebd6689d8c64011118478db0c61a89aa2646c860df401de476fbf378983'
        );
        incentiveCalculator.setModeLiqIncentiveMultiplier_e18(modes, multipliers);
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x1e46cebd6689d8c64011118478db0c61a89aa2646c860df401de476fbf378983'
        );
        incentiveCalculator.setTokenLiqIncentiveMultiplier_e18(tokens, multipliers);
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x1e46cebd6689d8c64011118478db0c61a89aa2646c860df401de476fbf378983'
        );
        incentiveCalculator.setMaxLiqIncentiveMultiplier_e18(1e18);
        vm.stopPrank();
    }

    function testRiskManager() public {
        address[] memory tokens;
        uint128[] memory amts;
        vm.startPrank(ALICE, ALICE);
        vm.expectRevert(bytes('#101'));
        riskManager.updateModeDebtShares(1, address(0), 0);
        vm.expectRevert(
            'AccessControl: account 0x00000000000000000000000000000000000a11ce is missing role 0x8fbcb4375b910093bcf636b6b2f26b26eda2a29ef5a8ee7de44b5743c3bf9a28'
        );
        riskManager.setModeDebtCeilingInfo(0, tokens, amts);
        vm.stopPrank();
    }
}
