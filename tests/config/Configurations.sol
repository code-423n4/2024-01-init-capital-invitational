// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {PoolConfig, ModeStatus} from '../../contracts/interfaces/core/IConfig.sol';
import {PythOracleReader} from '../../contracts/oracle/PythOracleReader.sol';
import {Constants} from './Constants.sol';

contract Configurations is Constants {
    // storage
    PoolConfiguration[] public poolConfigs;
    ModeConfiguration[] public modeConfigs;
    OracleConfiguration oracleConfig;

    struct PoolConfiguration {
        address underlyingToken;
        PoolConfig poolConfig;
        uint incentiveMultiplier_e18;
    }

    struct OracleConfiguration {
        address[] tokens;
        bytes32[] api3DataFeedIds;
        uint[] api3MaxStaleTimes;
        bytes32[] pythPriceFeedIds;
        uint[] pythMaxStaleTimes;
        uint[] maxPriceDeviations_e18;
    }

    struct ModeConfiguration {
        uint8 mode;
        address[] tokens;
        uint128[] collateralFactors_e18;
        uint128[] borrowFactors_e18;
        uint64 targetHealthAfterLiquidation_e18;
        ModeStatus status;
        uint incentiveMultiplier_e18;
        uint128[] debtCeilingAmts;
    }

    function _prepareConfigs() internal {
        _preparePoolConfigs();
        _prepareModeConfigs();
        _prepareOracleConfigs();
    }

    function _preparePoolConfigs() internal {
        // WBTC
        poolConfigs.push(
            PoolConfiguration({
                underlyingToken: WBTC,
                poolConfig: PoolConfig({
                    supplyCap: type(uint128).max,
                    borrowCap: type(uint128).max,
                    canMint: true,
                    canBurn: true,
                    canBorrow: true,
                    canRepay: true,
                    canFlash: true
                }),
                incentiveMultiplier_e18: 0.9e18
            })
        );
        //WETH
        poolConfigs.push(
            PoolConfiguration({
                underlyingToken: WETH,
                poolConfig: PoolConfig({
                    supplyCap: type(uint128).max,
                    borrowCap: type(uint128).max,
                    canMint: true,
                    canBurn: true,
                    canBorrow: true,
                    canRepay: true,
                    canFlash: true
                }),
                incentiveMultiplier_e18: 0.9e18
            })
        );
        // USDC
        poolConfigs.push(
            PoolConfiguration({
                underlyingToken: USDC,
                poolConfig: PoolConfig({
                    supplyCap: type(uint128).max,
                    borrowCap: type(uint128).max,
                    canMint: true,
                    canBurn: true,
                    canBorrow: true,
                    canRepay: true,
                    canFlash: true
                }),
                incentiveMultiplier_e18: 0.5e18
            })
        );
        // USDT
        poolConfigs.push(
            PoolConfiguration({
                underlyingToken: USDT,
                poolConfig: PoolConfig({
                    supplyCap: type(uint128).max,
                    borrowCap: type(uint128).max,
                    canMint: true,
                    canBurn: true,
                    canBorrow: true,
                    canRepay: true,
                    canFlash: true
                }),
                incentiveMultiplier_e18: 0.5e18
            })
        );
        // WMNT
        poolConfigs.push(
            PoolConfiguration({
                underlyingToken: WMNT,
                poolConfig: PoolConfig({
                    supplyCap: type(uint128).max,
                    borrowCap: type(uint128).max,
                    canMint: true,
                    canBurn: true,
                    canBorrow: true,
                    canRepay: true,
                    canFlash: true
                }),
                incentiveMultiplier_e18: 1e18
            })
        );
        // USDY
        poolConfigs.push(
            PoolConfiguration({
                underlyingToken: USDY,
                poolConfig: PoolConfig({
                    supplyCap: type(uint128).max,
                    borrowCap: type(uint128).max,
                    canMint: true,
                    canBurn: true,
                    canBorrow: true,
                    canRepay: true,
                    canFlash: true
                }),
                incentiveMultiplier_e18: 0.5e18
            })
        );
    }

    function _prepareModeConfigs() internal {
        // sorted pool orders
        // WMNT WETH_USDT_UNI_V2 USDY USDT WETH WBTC

        // Mode 1 General
        address[] memory mode1Tokens = new address[](5);
        mode1Tokens[0] = WMNT;
        mode1Tokens[1] = USDY; // NOTE: usdy has no oracle yet, add to see if it works on deposit/withdraw
        mode1Tokens[2] = USDT;
        mode1Tokens[3] = WETH;
        mode1Tokens[4] = WBTC;

        uint128[] memory mode1CollateralFactors = new uint128[](5);
        mode1CollateralFactors[0] = 869e15; // WMNT: 0.869
        mode1CollateralFactors[1] = 952e15; // USDY: 0.952
        mode1CollateralFactors[2] = 952e15; // USDT: 0.952
        mode1CollateralFactors[3] = 909e15; // WETH 0.909
        mode1CollateralFactors[4] = 909e15; // WBTC 0.909
        uint128[] memory mode1BorrowFactors = new uint128[](5);
        mode1BorrowFactors[0] = 115e16; // WMNT: 1.15
        mode1BorrowFactors[1] = 105e16; // USDY: 1.05
        mode1BorrowFactors[2] = 105e16; // USDT: 1.05
        mode1BorrowFactors[3] = 11e17; // WETH: 1.1
        mode1BorrowFactors[4] = 11e17; // WBTC: 1.1
        uint128[] memory debtCeilings1 = new uint128[](5);
        debtCeilings1[0] = 1_000_000e18; //WMNT
        debtCeilings1[1] = 0; //USDY
        debtCeilings1[2] = 800_000e18; //USDT
        debtCeilings1[3] = 800e18; //WETH
        debtCeilings1[4] = 80e8; //WBTC

        modeConfigs.push(
            ModeConfiguration({
                mode: 1,
                tokens: mode1Tokens,
                collateralFactors_e18: mode1CollateralFactors,
                borrowFactors_e18: mode1BorrowFactors,
                targetHealthAfterLiquidation_e18: 1.2e18,
                status: ModeStatus({canCollateralize: true, canDecollateralize: true, canBorrow: true, canRepay: true}),
                incentiveMultiplier_e18: 1e18,
                debtCeilingAmts: debtCeilings1
            })
        );

        // Mode2 None-Stable
        address[] memory mode2Tokens = new address[](3);
        mode2Tokens[0] = WMNT;
        mode2Tokens[1] = WETH;
        mode2Tokens[2] = WBTC;
        uint128[] memory mode2CollateralFactors = new uint128[](3);
        mode2CollateralFactors[0] = 909e15; // WMNT: 0.909
        mode2CollateralFactors[1] = 952e15; // WETH 0.952
        mode2CollateralFactors[2] = 926e15; // WBTC 0.926
        uint128[] memory mode2BorrowFactors = new uint128[](3);
        mode2BorrowFactors[0] = 115e16; // WMNT: 1.15
        mode2BorrowFactors[1] = 11e17; // WETH: 1.1
        mode2BorrowFactors[2] = 11e17; // WBTC: 1.1
        uint128[] memory debtCeilings2 = new uint128[](3);
        debtCeilings2[0] = 500_000e18; //WMNT
        debtCeilings2[1] = 400e18; // WETH
        debtCeilings2[2] = 40e8; // WBTC

        modeConfigs.push(
            ModeConfiguration({
                mode: 2,
                tokens: mode2Tokens,
                collateralFactors_e18: mode2CollateralFactors,
                borrowFactors_e18: mode2BorrowFactors,
                targetHealthAfterLiquidation_e18: 1.2e18,
                status: ModeStatus({canCollateralize: true, canDecollateralize: true, canBorrow: true, canRepay: true}),
                incentiveMultiplier_e18: 0.9e18,
                debtCeilingAmts: debtCeilings2
            })
        );

        // Mode3 lp
        address[] memory mode3Tokens = new address[](4);
        mode3Tokens[0] = WETH_USDC_MOE;
        mode3Tokens[1] = WETH_USDT_UNI_V2;
        mode3Tokens[2] = USDT;
        mode3Tokens[3] = WETH;
        uint128[] memory mode3CollateralFactors = new uint128[](4);
        mode3CollateralFactors[0] = 909e15; // WETH_USDC_MOE 0.909
        mode3CollateralFactors[1] = 909e15; // WETH_USDT_UNI_V2 0.909
        mode3CollateralFactors[2] = 952e15; // USDT: 0.952
        mode3CollateralFactors[3] = 909e15; // WETH: 0.909
        uint128[] memory mode3BorrowFactors = new uint128[](4);
        mode3BorrowFactors[0] = 11e17; // WETH_USDC_MOE: 1.1
        mode3BorrowFactors[1] = 11e17; // WETH_USDT_UNI_V2: 1.1
        mode3BorrowFactors[2] = 11e17; // WETH: 1.1
        mode3BorrowFactors[3] = 105e16; // USDT: 1.05
        uint128[] memory debtCeilings3 = new uint128[](4);
        debtCeilings3[0] = 500e18;
        debtCeilings3[1] = 500e18;
        debtCeilings3[2] = 500e18;
        debtCeilings3[3] = 500e18;

        modeConfigs.push(
            ModeConfiguration({
                mode: 3,
                tokens: mode3Tokens,
                collateralFactors_e18: mode3CollateralFactors,
                borrowFactors_e18: mode3BorrowFactors,
                targetHealthAfterLiquidation_e18: type(uint64).max,
                status: ModeStatus({canCollateralize: true, canDecollateralize: true, canBorrow: true, canRepay: true}),
                incentiveMultiplier_e18: 0.9e18,
                debtCeilingAmts: debtCeilings3
            })
        );
    }

    function _prepareOracleConfigs() internal {
        oracleConfig.tokens = new address[](5);
        oracleConfig.api3DataFeedIds = new bytes32[](5);
        oracleConfig.api3MaxStaleTimes = new uint[](5);
        oracleConfig.pythPriceFeedIds = new bytes32[](5);
        oracleConfig.pythMaxStaleTimes = new uint[](5);
        oracleConfig.maxPriceDeviations_e18 = new uint[](5);

        // WBTC
        oracleConfig.tokens[0] = WBTC;
        oracleConfig.api3DataFeedIds[0] = WBTC_DATA_FEED_ID;
        oracleConfig.api3MaxStaleTimes[0] = type(uint).max;
        oracleConfig.pythPriceFeedIds[0] = WBTC_PRICE_FEED_ID;
        oracleConfig.pythMaxStaleTimes[0] = type(uint).max;
        oracleConfig.maxPriceDeviations_e18[0] = type(uint).max;

        // WETH
        oracleConfig.tokens[1] = WETH;
        oracleConfig.api3DataFeedIds[1] = ETH_DATA_FEED_ID;
        oracleConfig.api3MaxStaleTimes[1] = type(uint).max;
        oracleConfig.pythPriceFeedIds[1] = ETH_PRICE_FEED_ID;
        oracleConfig.pythMaxStaleTimes[1] = type(uint).max;
        oracleConfig.maxPriceDeviations_e18[1] = type(uint).max;

        // USDC
        oracleConfig.tokens[2] = USDC;
        oracleConfig.api3DataFeedIds[2] = USDC_DATA_FEED_ID;
        oracleConfig.api3MaxStaleTimes[2] = type(uint).max;
        oracleConfig.pythPriceFeedIds[2] = USDC_PRICE_FEED_ID;
        oracleConfig.pythMaxStaleTimes[2] = type(uint).max;
        oracleConfig.maxPriceDeviations_e18[2] = type(uint).max;

        // USDT
        oracleConfig.tokens[3] = USDT;
        oracleConfig.api3DataFeedIds[3] = USDT_DATA_FEED_ID;
        oracleConfig.api3MaxStaleTimes[3] = type(uint).max;
        oracleConfig.pythPriceFeedIds[3] = USDT_PRICE_FEED_ID;
        oracleConfig.pythMaxStaleTimes[3] = type(uint).max;
        oracleConfig.maxPriceDeviations_e18[3] = type(uint).max;

        // WMNT
        oracleConfig.tokens[4] = WMNT;
        oracleConfig.api3DataFeedIds[4] = MNT_DATA_FEED_ID;
        oracleConfig.api3MaxStaleTimes[4] = type(uint).max;
        oracleConfig.pythPriceFeedIds[4] = MNT_PRICE_FEED_ID;
        oracleConfig.pythMaxStaleTimes[4] = type(uint).max;
        oracleConfig.maxPriceDeviations_e18[4] = type(uint).max;
    }
}
