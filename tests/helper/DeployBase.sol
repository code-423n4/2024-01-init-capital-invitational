// SPDX-License-Identifier: UNLICENSEDsetHealthMultiplierFactorE18
pragma solidity ^0.8.19;

import {IERC20Metadata} from '@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol';
import {TransparentUpgradeableProxy} from '@openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol';
import {TransparentUpgradeableProxyReceiveETH} from '../../contracts/common/TransparentUpgradeableProxyReceiveETH.sol';
import {ProxyAdmin} from '@openzeppelin-contracts/proxy/transparent/ProxyAdmin.sol';

import {AccessControlManager} from '../../contracts/common/AccessControlManager.sol';

// import oracle contracts
import {InitOracle} from '../../contracts/oracle/InitOracle.sol';
import {Api3OracleReader} from '../../contracts/oracle/Api3OracleReader.sol';
import {PythOracleReader} from '../../contracts/oracle/PythOracleReader.sol';

// import core contracts
import {Config} from '../../contracts/core/Config.sol';

import {LiqIncentiveCalculator} from '../../contracts/core/LiqIncentiveCalculator.sol';
import {InitCore} from '../../contracts/core/InitCore.sol';
import {PosManager} from '../../contracts/core/PosManager.sol';
import {RiskManager} from '../../contracts/risk_manager/RiskManager.sol';

// import lending pool contracts
import {DoubleSlopeIRM} from '../../contracts/lending_pool/DoubleSlopeIRM.sol';
import {LendingPool} from '../../contracts/lending_pool/LendingPool.sol';

// import plugins
import {MockWLpUniV2} from '../../contracts/mock/MockWLpUniV2.sol';
import {WrapCenter} from '../../contracts/mock/WrapCenter.sol';
import {mUSDUSDYHelper} from '../../contracts/helper/rebase_helper/mUSDUSDYHelper.sol';
import {MoneyMarketHook} from '../../contracts/hook/MoneyMarketHook.sol';
import {InitLens} from '../../contracts/helper/InitLens.sol';
import {WLpMoeMasterChef} from '../../contracts/wrapper/WLpMoeMasterChef.sol';

// import configurations
import {Configurations} from '../config/Configurations.sol';

import {console2} from '@forge-std/console2.sol';

contract DeployBase is Configurations {
    // Access Control
    AccessControlManager accessControlManager;
    ProxyAdmin proxyAdmin;

    // Oracles
    InitOracle public initOracle;
    Api3OracleReader public api3OracleReader;
    PythOracleReader public pythOracleReader;

    // Core
    Config public config;
    LiqIncentiveCalculator public incentiveCalculator;
    InitCore public initCore;
    PosManager public positionManager;
    RiskManager public riskManager;

    // lending pools
    DoubleSlopeIRM doubleSlopeIRM;
    mapping(address => LendingPool) lendingPools; // underlying tokens -> lending pools

    // plugins
    WrapCenter public wrapCenter;
    mUSDUSDYHelper public musdusdyWrapHelper;
    MockWLpUniV2 public mockWLpUniV2;
    MoneyMarketHook public moneyMarketHook;
    InitLens public initLens;
    WLpMoeMasterChef public wLpMoeMasterChef;

    // MockSwapStrat public mockSwapStrat;

    function _deploy() internal {
        // configurations
        _prepareConfigs();
        // deploys
        _deployCommon();
        _deployOracle();
        _deployCore();
        _deployLendingPools();
        _deployPlugins();
    }

    function _deployCommon() internal {
        proxyAdmin = new ProxyAdmin();
        accessControlManager = new AccessControlManager();
        accessControlManager.grantRole(keccak256('guardian'), ADMIN);
        accessControlManager.grantRole(keccak256('governor'), ADMIN);
    }

    // Deploy Oracle
    function _deployOracle() internal {
        // deploy Api3
        Api3OracleReader api3OracleReaderImpl = new Api3OracleReader(address(accessControlManager));
        api3OracleReader = Api3OracleReader(
            address(
                new TransparentUpgradeableProxy(
                    address(api3OracleReaderImpl),
                    address(proxyAdmin),
                    abi.encodeWithSelector(api3OracleReaderImpl.initialize.selector, API3_SERVER_1)
                )
            )
        );

        // deployPyth
        PythOracleReader pythOracleReaderImpl = new PythOracleReader(address(accessControlManager));
        pythOracleReader = PythOracleReader(
            address(
                new TransparentUpgradeableProxy(
                    address(pythOracleReaderImpl),
                    address(proxyAdmin),
                    abi.encodeWithSelector(pythOracleReaderImpl.initialize.selector, PYTH_MANTLE)
                )
            )
        );

        // deploy init oracle
        InitOracle initOracleImpl = new InitOracle(address(accessControlManager));
        initOracle = InitOracle(
            address(
                new TransparentUpgradeableProxy(
                    address(initOracleImpl),
                    address(proxyAdmin),
                    abi.encodeWithSelector(initOracleImpl.initialize.selector)
                )
            )
        );
    }

    // Deploy Core contracts
    function _deployCore() internal {
        // deploy configuration
        _deployConfig();
        // deploy Incentive calculator
        _deployIncentiveCalculator();
        // deploy PM and Proxy
        _deployPositionManager();
        // deploy Core and Proxy
        _deployInitCore();
        // deply Risk Manager and Proxy
        _deployRiskManager();
        // initialize the position manager proxy
        positionManager.initialize(TOKEN_NAME, TOKEN_SYMBOL, address(initCore), MAX_COLL_COUNT);
        // initialize the initcore proxy
        initCore.initialize(address(config), address(initOracle), address(incentiveCalculator), address(riskManager));
    }

    function _deployConfig() internal {
        Config configImpl = new Config(address(accessControlManager));
        config = Config(
            address(
                new TransparentUpgradeableProxy(
                    address(configImpl),
                    address(proxyAdmin),
                    abi.encodeWithSelector(configImpl.initialize.selector, address(accessControlManager))
                )
            )
        );
    }

    function _deployIncentiveCalculator() internal {
        LiqIncentiveCalculator liqIncentiveCalculatorImpl = new LiqIncentiveCalculator(address(accessControlManager));
        incentiveCalculator = LiqIncentiveCalculator(
            address(
                new TransparentUpgradeableProxy(
                    address(liqIncentiveCalculatorImpl),
                    address(proxyAdmin),
                    abi.encodeWithSelector(LiqIncentiveCalculator.initialize.selector, MAX_INCENTIVE_MULTIPLIER_E18)
                )
            )
        );
    }

    function _deployPositionManager() internal {
        PosManager positionManagerImpl = new PosManager(address(accessControlManager));
        positionManager = PosManager(
            address(new TransparentUpgradeableProxy(address(positionManagerImpl), address(proxyAdmin), bytes('')))
        );
    }

    function _deployRiskManager() internal {
        RiskManager riskManagerImpl = new RiskManager(address(initCore), address(accessControlManager));
        riskManager = RiskManager(
            address(
                new TransparentUpgradeableProxy(
                    address(riskManagerImpl),
                    address(proxyAdmin),
                    abi.encodeWithSelector(RiskManager.initialize.selector)
                )
            )
        );
    }

    function _deployInitCore() public {
        InitCore initCoreImpl = new InitCore(address(positionManager), address(accessControlManager));
        initCore =
            InitCore(address(new TransparentUpgradeableProxy(address(initCoreImpl), address(proxyAdmin), bytes(''))));
    }

    // Deploy Lending Pools contracts
    function _deployLendingPools() internal {
        doubleSlopeIRM =
            new DoubleSlopeIRM(BASE_BORR_RATE_E18, JUMP_UTIL_E18, BORR_RATE_MULTIPLIER_E18, JUMP_MULTIPLIER_E18);

        LendingPool lendingPoolImpl = new LendingPool(address(initCore), address(accessControlManager));
        for (uint i; i < poolConfigs.length; ++i) {
            address token = poolConfigs[i].underlyingToken;
            string memory symbol = IERC20Metadata(token).symbol();
            lendingPools[token] = LendingPool(
                address(
                    new TransparentUpgradeableProxy(
                        address(lendingPoolImpl),
                        address(proxyAdmin),
                        abi.encodeWithSelector(
                            LendingPool.initialize.selector,
                            token,
                            string(abi.encodePacked('Init ', symbol)),
                            string(abi.encodePacked('i', symbol)),
                            address(doubleSlopeIRM),
                            RESERVE_FACTOR_E18,
                            TREASURY
                        )
                    )
                )
            );
        }
    }

    // Deploy Plugins
    function _deployPlugins() internal {
        wrapCenter = new WrapCenter(address(initCore), WMNT);
        mockWLpUniV2 = new MockWLpUniV2(FUSION_X_V2_FACTORY);
        musdusdyWrapHelper = new mUSDUSDYHelper(USDY, mUSD);
        initLens = new InitLens(address(initCore), address(positionManager), address(riskManager), address(config));
        MoneyMarketHook moneyMarketHookImpl =
            new MoneyMarketHook(address(initCore), WMNT, address(accessControlManager));
        moneyMarketHook = MoneyMarketHook(
            payable(
                address(
                    new TransparentUpgradeableProxyReceiveETH(
                        address(moneyMarketHookImpl),
                        address(proxyAdmin),
                        abi.encodeWithSelector(MoneyMarketHook.initialize.selector, bytes(''))
                    )
                )
            )
        );
        WLpMoeMasterChef wLpMoeMasterChefImpl = new WLpMoeMasterChef(MOE_MASTER_CHEF, MOE_FACTORY, WMNT);

        wLpMoeMasterChef = WLpMoeMasterChef(
            payable(
                address(
                    new TransparentUpgradeableProxy(
                        address(wLpMoeMasterChefImpl),
                        address(proxyAdmin),
                        abi.encodeWithSelector(
                            WLpMoeMasterChef.initialize.selector, string('wrapLpMoe'), string('wLpMoe')
                        )
                    )
                )
            )
        );
    }

    // set configurations
    function _setConfigs() internal {
        // set pool configurations
        for (uint i = 0; i < poolConfigs.length; ++i) {
            config.setPoolConfig(address(lendingPools[poolConfigs[i].underlyingToken]), poolConfigs[i].poolConfig);
        }

        // set mode configurations
        for (uint i; i < modeConfigs.length; ++i) {
            ModeConfiguration memory modeConfig = modeConfigs[i];
            address[] memory lendingPoolList = new address[](modeConfig.tokens.length);
            for (uint j; j < modeConfig.tokens.length; j++) {
                if (i == 2 && j == 0) {
                    // use lp token
                    lendingPoolList[j] = modeConfig.tokens[0];
                    continue;
                }
                // set add token itself if it is Lp token
                address modeToken = modeConfig.tokens[j];
                if (address(lendingPools[modeToken]) == address(0)) {
                    lendingPoolList[j] = modeToken;
                } else {
                    lendingPoolList[j] = address(lendingPools[modeToken]);
                }
            }
            config.setCollFactors_e18(modeConfig.mode, lendingPoolList, modeConfig.collateralFactors_e18);
            config.setBorrFactors_e18(modeConfig.mode, lendingPoolList, modeConfig.borrowFactors_e18);
            config.setModeStatus(modeConfig.mode, modeConfig.status);
            config.setMaxHealthAfterLiq_e18(modeConfig.mode, modeConfig.targetHealthAfterLiquidation_e18);
            riskManager.setModeDebtCeilingInfo(modeConfig.mode, lendingPoolList, modeConfig.debtCeilingAmts);
        }

        // oracle configurations
        api3OracleReader.setDataFeedIds(oracleConfig.tokens, oracleConfig.api3DataFeedIds);
        api3OracleReader.setMaxStaleTimes(oracleConfig.tokens, oracleConfig.api3MaxStaleTimes);
        pythOracleReader.setPriceIds(oracleConfig.tokens, oracleConfig.pythPriceFeedIds);
        pythOracleReader.setMaxStaleTimes(oracleConfig.tokens, oracleConfig.pythMaxStaleTimes);
        uint tokenLength = oracleConfig.tokens.length;
        address[] memory primarySources = new address[](tokenLength);
        address[] memory secondarySources = new address[](tokenLength);
        for (uint i; i < tokenLength; ++i) {
            primarySources[i] = address(api3OracleReader);
            secondarySources[i] = address(pythOracleReader);
        }
        initOracle.setPrimarySources(oracleConfig.tokens, primarySources);
        initOracle.setSecondarySources(oracleConfig.tokens, secondarySources);
        initOracle.setMaxPriceDeviations_e18(oracleConfig.tokens, oracleConfig.maxPriceDeviations_e18);

        // incentiveCalculator configurations
        // mode incentive
        uint modeConfigLength = modeConfigs.length;
        uint16[] memory modes = new uint16[](modeConfigLength);
        uint[] memory modeIncentiveMultipliers_e18 = new uint[](modeConfigLength);
        for (uint i; i < modeConfigs.length; ++i) {
            modes[i] = modeConfigs[i].mode;
            modeIncentiveMultipliers_e18[i] = modeConfigs[i].incentiveMultiplier_e18;
        }
        incentiveCalculator.setModeLiqIncentiveMultiplier_e18(modes, modeIncentiveMultipliers_e18);

        // token incentive
        uint poolConfigsLength = poolConfigs.length;
        address[] memory tokenIncentives = new address[](poolConfigsLength);
        uint[] memory tokenIncentiveMultipliers_e18 = new uint[](poolConfigsLength);
        for (uint i; i < poolConfigsLength; ++i) {
            tokenIncentives[i] = poolConfigs[i].underlyingToken;
            tokenIncentiveMultipliers_e18[i] = poolConfigs[i].incentiveMultiplier_e18;
        }
        incentiveCalculator.setTokenLiqIncentiveMultiplier_e18(tokenIncentives, tokenIncentiveMultipliers_e18);
    }
}
