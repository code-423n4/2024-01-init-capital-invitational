# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | Using bools for storage incurs overhead | 4 |
| [GAS-2](#GAS-2) | Cache array length outside of loop | 46 |
| [GAS-3](#GAS-3) | For Operations that will not overflow, you could use unchecked | 756 |
| [GAS-4](#GAS-4) | Functions guaranteed to revert when called by normal users can be marked `payable` | 34 |
| [GAS-5](#GAS-5) | `++i` costs less gas than `i++`, especially when it's used in `for`-loops (`--i`/`i--` too) | 1 |
| [GAS-6](#GAS-6) | Splitting require() statements that use && saves gas | 4 |
| [GAS-7](#GAS-7) | Use != 0 instead of > 0 for unsigned integer comparison | 14 |
### <a name="GAS-1"></a>[GAS-1] Using bools for storage incurs overhead
Use uint256(1) and uint256(2) for true/false to avoid a Gwarmaccess (100 gas), and to avoid Gsset (20000 gas) when changing from ‘false’ to ‘true’, after having been ‘true’ in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

*Instances (4)*:
```solidity
File: contracts/core/Config.sol

24:     mapping(address => bool) public whitelistedWLps; // @inheritdoc IConfig

```

```solidity
File: contracts/core/InitCore.sol

47:     bool internal isMulticallTx;

```

```solidity
File: contracts/core/PosManager.sol

39:     mapping(address => mapping(uint => bool)) public isCollateralized; // @inheritdoc IPosManager

```

```solidity
File: contracts/hook/MoneyMarketHook.sol

45:     mapping(address => bool) public whitelistedHelpers;

```

### <a name="GAS-2"></a>[GAS-2] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (46)*:
```solidity
File: contracts/common/Multicall.sol

14:         for (uint i; i < _data.length; i = i.uinc()) {

```

```solidity
File: contracts/core/Config.sol

110:         for (uint i; i < _pools.length; i = i.uinc()) {

127:         for (uint i; i < _pools.length; i = i.uinc()) {

159:         for (uint i; i < _wLps.length; i = i.uinc()) {

```

```solidity
File: contracts/core/InitCore.sol

189:         for (uint i; i < pools.length; i = i.uinc()) {

192:         for (uint i; i < wLps.length; i = i.uinc()) {

195:             for (uint j; j < ids[i].length; j = j.uinc()) {

208:         for (uint i; i < pools.length; i = i.uinc()) {

374:         uint[] memory balanceBefores = new uint[](_pools.length);

377:         for (uint i; i < _pools.length; i = i.uinc()) {

391:         for (uint i; i < _pools.length; i = i.uinc()) {

404:         for (uint i; i < posIds.length; i = i.uinc()) {

467:         for (uint i; i < pools.length; i = i.uinc()) {

474:         for (uint i; i < wLps.length; i = i.uinc()) {

475:             for (uint j; j < ids[i].length; j = j.uinc()) {

493:         for (uint i; i < pools.length; i = i.uinc()) {

```

```solidity
File: contracts/core/LiqIncentiveCalculator.sol

73:         for (uint i; i < _modes.length; i = i.uinc()) {

86:         for (uint i; i < _tokens.length; i = i.uinc()) {

104:         for (uint i; i < _modes.length; i = i.uinc()) {

```

```solidity
File: contracts/core/PosManager.sol

85:         for (uint i; i < pools.length; i = i.uinc()) {

116:         for (uint i; i < pools.length; i = i.uinc()) {

122:         for (uint i; i < wLps.length; i = i.uinc()) {

125:             for (uint j; j < ids[i].length; j = j.uinc()) {

279:             if (posCollInfo.ids[_wLp].length() == 0) {

317:         for (uint i; i < _tokens.length; i = i.uinc()) {

329:         for (uint i; i < tokens.length; i = i.uinc()) {

```

```solidity
File: contracts/hook/MoneyMarketHook.sol

89:         for (uint i; i < _params.withdrawParams.length; i = i.uinc()) {

115:         for (uint i; i < _helpers.length; i = i.uinc()) {

180:         for (uint i; i < _params.length; i = i.uinc()) {

212:         for (uint i; i < _params.length; i = i.uinc()) {

254:         for (uint i; i < _params.length; i = i.uinc()) {

277:         for (uint i; i < _params.length; i = i.uinc()) {

```

```solidity
File: contracts/oracle/Api3OracleReader.sol

51:         for (uint i; i < _dataFeedIds.length; i = i.uinc()) {

67:         for (uint i; i < _maxStaleTimes.length; i = i.uinc()) {

```

```solidity
File: contracts/oracle/InitOracle.sol

88:         for (uint i; i < _tokens.length; i = i.uinc()) {

96:         for (uint i; i < _tokens.length; i = i.uinc()) {

105:         for (uint i; i < _tokens.length; i = i.uinc()) {

117:         for (uint i; i < _tokens.length; i = i.uinc()) {

```

```solidity
File: contracts/risk_manager/RiskManager.sol

86:         for (uint i; i < _pools.length; i = i.uinc()) {

```

```solidity
File: contracts/wrapper/WLpMoeMasterChef.sol

70:         uint[] memory rewardBeforeAmts = new uint[](___rewardTokens.length);

71:         for (uint i; i < ___rewardTokens.length; i = i.uinc()) {

78:         for (uint i; i < ___rewardTokens.length; i = i.uinc()) {

134:         for (uint i; i < ___rewardTokens.length; i = i.uinc()) {

247:         for (uint i; i < tokens.length; i = i.uinc()) {

262:         for (uint i; i < tokens.length; i = i.uinc()) {

317:         for (uint i; i < tokens.length; i = i.uinc()) {

```

### <a name="GAS-3"></a>[GAS-3] For Operations that will not overflow, you could use unchecked

*Instances (756)*:
```solidity
File: contracts/common/AccessControlManager.sol

4: import '@openzeppelin-contracts/access/AccessControlDefaultAdminRules.sol';

4: import '@openzeppelin-contracts/access/AccessControlDefaultAdminRules.sol';

4: import '@openzeppelin-contracts/access/AccessControlDefaultAdminRules.sol';

5: import {IAccessControlManager} from '../interfaces/common/IAccessControlManager.sol';

5: import {IAccessControlManager} from '../interfaces/common/IAccessControlManager.sol';

5: import {IAccessControlManager} from '../interfaces/common/IAccessControlManager.sol';

```

```solidity
File: contracts/common/Multicall.sol

4: import '../interfaces/common/IMulticall.sol';

4: import '../interfaces/common/IMulticall.sol';

4: import '../interfaces/common/IMulticall.sol';

5: import '../common/library/UncheckedIncrement.sol';

5: import '../common/library/UncheckedIncrement.sol';

5: import '../common/library/UncheckedIncrement.sol';

19:                     revert(message); // revert if call does not succeed

19:                     revert(message); // revert if call does not succeed

21:                     revert('MC'); // default revert message if things go wrong

21:                     revert('MC'); // default revert message if things go wrong

38:         paddedData[63] = 0x40; // modify the memory offset to follow the first 64 bytes

38:         paddedData[63] = 0x40; // modify the memory offset to follow the first 64 bytes

```

```solidity
File: contracts/common/TransparentUpgradeableProxyReceiveETH.sol

4: import {TransparentUpgradeableProxy} from '@openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

4: import {TransparentUpgradeableProxy} from '@openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

4: import {TransparentUpgradeableProxy} from '@openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

4: import {TransparentUpgradeableProxy} from '@openzeppelin-contracts/proxy/transparent/TransparentUpgradeableProxy.sol';

```

```solidity
File: contracts/common/UnderACM.sol

4: import {IAccessControlManager} from '../interfaces/common/IAccessControlManager.sol';

4: import {IAccessControlManager} from '../interfaces/common/IAccessControlManager.sol';

4: import {IAccessControlManager} from '../interfaces/common/IAccessControlManager.sol';

8:     IAccessControlManager public immutable ACM; // access control manager

8:     IAccessControlManager public immutable ACM; // access control manager

```

```solidity
File: contracts/common/library/UncheckedIncrement.sol

7:             return self + 1;

```

```solidity
File: contracts/core/Config.sol

4: import '../common/library/InitErrors.sol';

4: import '../common/library/InitErrors.sol';

4: import '../common/library/InitErrors.sol';

5: import '../common/library/ArrayLib.sol';

5: import '../common/library/ArrayLib.sol';

5: import '../common/library/ArrayLib.sol';

9: } from '../interfaces/core/IConfig.sol';

9: } from '../interfaces/core/IConfig.sol';

9: } from '../interfaces/core/IConfig.sol';

10: import {UnderACM} from '../common/UnderACM.sol';

10: import {UnderACM} from '../common/UnderACM.sol';

12: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

12: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

12: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

12: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

12: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

24:     mapping(address => bool) public whitelistedWLps; // @inheritdoc IConfig

24:     mapping(address => bool) public whitelistedWLps; // @inheritdoc IConfig

```

```solidity
File: contracts/core/InitCore.sol

4: import {Multicall} from '../common/Multicall.sol';

4: import {Multicall} from '../common/Multicall.sol';

5: import '../common/library/InitErrors.sol';

5: import '../common/library/InitErrors.sol';

5: import '../common/library/InitErrors.sol';

6: import '../common/library/ArrayLib.sol';

6: import '../common/library/ArrayLib.sol';

6: import '../common/library/ArrayLib.sol';

7: import {UnderACM} from '../common/UnderACM.sol';

7: import {UnderACM} from '../common/UnderACM.sol';

9: import {IInitCore} from '../interfaces/core/IInitCore.sol';

9: import {IInitCore} from '../interfaces/core/IInitCore.sol';

9: import {IInitCore} from '../interfaces/core/IInitCore.sol';

10: import {IPosManager} from '../interfaces/core/IPosManager.sol';

10: import {IPosManager} from '../interfaces/core/IPosManager.sol';

10: import {IPosManager} from '../interfaces/core/IPosManager.sol';

11: import {PoolConfig, TokenFactors, ModeStatus, IConfig} from '../interfaces/core/IConfig.sol';

11: import {PoolConfig, TokenFactors, ModeStatus, IConfig} from '../interfaces/core/IConfig.sol';

11: import {PoolConfig, TokenFactors, ModeStatus, IConfig} from '../interfaces/core/IConfig.sol';

12: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

12: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

12: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

13: import {IBaseWrapLp} from '../interfaces/wrapper/IBaseWrapLp.sol';

13: import {IBaseWrapLp} from '../interfaces/wrapper/IBaseWrapLp.sol';

13: import {IBaseWrapLp} from '../interfaces/wrapper/IBaseWrapLp.sol';

14: import {IInitOracle} from '../interfaces/oracle/IInitOracle.sol';

14: import {IInitOracle} from '../interfaces/oracle/IInitOracle.sol';

14: import {IInitOracle} from '../interfaces/oracle/IInitOracle.sol';

15: import {ILiqIncentiveCalculator} from '../interfaces/core/ILiqIncentiveCalculator.sol';

15: import {ILiqIncentiveCalculator} from '../interfaces/core/ILiqIncentiveCalculator.sol';

15: import {ILiqIncentiveCalculator} from '../interfaces/core/ILiqIncentiveCalculator.sol';

16: import {ICallbackReceiver} from '../interfaces/receiver/ICallbackReceiver.sol';

16: import {ICallbackReceiver} from '../interfaces/receiver/ICallbackReceiver.sol';

16: import {ICallbackReceiver} from '../interfaces/receiver/ICallbackReceiver.sol';

17: import {IFlashReceiver} from '../interfaces/receiver/IFlashReceiver.sol';

17: import {IFlashReceiver} from '../interfaces/receiver/IFlashReceiver.sol';

17: import {IFlashReceiver} from '../interfaces/receiver/IFlashReceiver.sol';

18: import {IRiskManager} from '../interfaces/risk_manager/IRiskManager.sol';

18: import {IRiskManager} from '../interfaces/risk_manager/IRiskManager.sol';

18: import {IRiskManager} from '../interfaces/risk_manager/IRiskManager.sol';

20: import {ReentrancyGuardUpgradeable} from '@openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';

20: import {ReentrancyGuardUpgradeable} from '@openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';

20: import {ReentrancyGuardUpgradeable} from '@openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';

20: import {ReentrancyGuardUpgradeable} from '@openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';

21: import {SafeCast} from '@openzeppelin-contracts/utils/math/SafeCast.sol';

21: import {SafeCast} from '@openzeppelin-contracts/utils/math/SafeCast.sol';

21: import {SafeCast} from '@openzeppelin-contracts/utils/math/SafeCast.sol';

21: import {SafeCast} from '@openzeppelin-contracts/utils/math/SafeCast.sol';

22: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

22: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

22: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

22: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

22: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

23: import {MathUpgradeable} from '@openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol';

23: import {MathUpgradeable} from '@openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol';

23: import {MathUpgradeable} from '@openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol';

23: import {MathUpgradeable} from '@openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol';

23: import {MathUpgradeable} from '@openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol';

24: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

24: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

24: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

24: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

25: import {EnumerableSet} from '@openzeppelin-contracts/utils/structs/EnumerableSet.sol';

25: import {EnumerableSet} from '@openzeppelin-contracts/utils/structs/EnumerableSet.sol';

25: import {EnumerableSet} from '@openzeppelin-contracts/utils/structs/EnumerableSet.sol';

25: import {EnumerableSet} from '@openzeppelin-contracts/utils/structs/EnumerableSet.sol';

43:     address public config; // @inheritdoc IInitCore

43:     address public config; // @inheritdoc IInitCore

44:     address public oracle; // @inheritdoc IInitCore

44:     address public oracle; // @inheritdoc IInitCore

45:     address public liqIncentiveCalculator; // @inheritdoc IInitCore

45:     address public liqIncentiveCalculator; // @inheritdoc IInitCore

46:     address public riskManager; // @inheritdoc IInitCore

46:     address public riskManager; // @inheritdoc IInitCore

48:     EnumerableSet.UintSet internal uncheckedPosIds; // posIds that need to be checked after multicall

48:     EnumerableSet.UintSet internal uncheckedPosIds; // posIds that need to be checked after multicall

140:         _require(ILendingPool(_pool).totalDebt() + _amt <= poolConfig.borrowCap, Errors.BORROW_CAP_REACHED);

211:             _riskManager.updateModeDebtShares(currentMode, pools[i], -shares[i].toInt256());

297:         _require(vars.config.isAllowedForCollateral(vars.mode, _poolOut), Errors.TOKEN_NOT_WHITELISTED); // config and mode are already stored

297:         _require(vars.config.isAllowedForCollateral(vars.mode, _poolOut), Errors.TOKEN_NOT_WHITELISTED); // config and mode are already stored

303:         vars.repayAmtWithLiqIncentive = (vars.repayAmt * vars.liqIncentive_e18) / ONE_E18;

303:         vars.repayAmtWithLiqIncentive = (vars.repayAmt * vars.liqIncentive_e18) / ONE_E18;

305:             uint[] memory prices_e36; // prices = [repayTokenPrice, collToken]

305:             uint[] memory prices_e36; // prices = [repayTokenPrice, collToken]

310:             shares = ILendingPool(_poolOut).toShares((vars.repayAmtWithLiqIncentive * prices_e36[0]) / prices_e36[1]);

310:             shares = ILendingPool(_poolOut).toShares((vars.repayAmtWithLiqIncentive * prices_e36[0]) / prices_e36[1]);

312:             shares = shares.min(IPosManager(POS_MANAGER).getCollAmt(_posId, _poolOut)); // take min of what's available

312:             shares = shares.min(IPosManager(POS_MANAGER).getCollAmt(_posId, _poolOut)); // take min of what's available

334:         _require(vars.config.whitelistedWLps(_wLp), Errors.TOKEN_NOT_WHITELISTED); // config is already stored

334:         _require(vars.config.whitelistedWLps(_wLp), Errors.TOKEN_NOT_WHITELISTED); // config is already stored

341:         vars.repayAmtWithLiqIncentive = (vars.repayAmt * vars.liqIncentive_e18) / ONE_E18;

341:         vars.repayAmtWithLiqIncentive = (vars.repayAmt * vars.liqIncentive_e18) / ONE_E18;

470:             uint tokenValue_e36 = ILendingPool(pools[i]).toAmtCurrent(shares[i]) * tokenPrice_e36;

472:             collCredit_e54 += tokenValue_e36 * factors.collFactor_e18;

472:             collCredit_e54 += tokenValue_e36 * factors.collFactor_e18;

477:                 uint wLpValue_e36 = amts[i][j] * wLpPrice_e36;

479:                 collCredit_e54 += wLpValue_e36 * factors.collFactor_e18;

479:                 collCredit_e54 += wLpValue_e36 * factors.collFactor_e18;

482:         collCredit_e36 = collCredit_e54 / ONE_E18;

497:             uint tokenValue_e36 = tokenPrice_e36 * ILendingPool(pools[i]).debtShareToAmtCurrent(debtShares[i]);

499:             borrowCredit_e54 += (tokenValue_e36 * factors.borrFactor_e18);

499:             borrowCredit_e54 += (tokenValue_e36 * factors.borrFactor_e18);

508:             ? (getCollateralCreditCurrent_e36(_posId) * ONE_E18) / borrowCredit_e36

508:             ? (getCollateralCreditCurrent_e36(_posId) * ONE_E18) / borrowCredit_e36

553:         IPosManager(POS_MANAGER).updatePosDebtShares(_posId, _pool, -sharesToRepay.toInt256());

557:         IRiskManager(riskManager).updateModeDebtShares(_mode, _pool, -sharesToRepay.toInt256());

```

```solidity
File: contracts/core/LiqIncentiveCalculator.sol

4: import '../common/library/InitErrors.sol';

4: import '../common/library/InitErrors.sol';

4: import '../common/library/InitErrors.sol';

5: import {Errors} from '../common/library/InitErrors.sol';

5: import {Errors} from '../common/library/InitErrors.sol';

5: import {Errors} from '../common/library/InitErrors.sol';

6: import {UncheckedIncrement} from '../common/library/UncheckedIncrement.sol';

6: import {UncheckedIncrement} from '../common/library/UncheckedIncrement.sol';

6: import {UncheckedIncrement} from '../common/library/UncheckedIncrement.sol';

7: import {UnderACM} from '../common/UnderACM.sol';

7: import {UnderACM} from '../common/UnderACM.sol';

8: import {ILiqIncentiveCalculator} from '../interfaces/core/ILiqIncentiveCalculator.sol';

8: import {ILiqIncentiveCalculator} from '../interfaces/core/ILiqIncentiveCalculator.sol';

8: import {ILiqIncentiveCalculator} from '../interfaces/core/ILiqIncentiveCalculator.sol';

10: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

10: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

10: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

10: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

10: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

11: import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';

11: import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';

11: import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';

11: import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';

21:     uint public maxLiqIncentiveMultiplier_e18; // @inheritdoc ILiqIncentiveCalculator

21:     uint public maxLiqIncentiveMultiplier_e18; // @inheritdoc ILiqIncentiveCalculator

22:     mapping(uint16 => uint) public modeLiqIncentiveMultiplier_e18; // @inheritdoc ILiqIncentiveCalculator

22:     mapping(uint16 => uint) public modeLiqIncentiveMultiplier_e18; // @inheritdoc ILiqIncentiveCalculator

23:     mapping(address => uint) public tokenLiqIncentiveMultiplier_e18; // @inheritdoc ILiqIncentiveCalculator

23:     mapping(address => uint) public tokenLiqIncentiveMultiplier_e18; // @inheritdoc ILiqIncentiveCalculator

24:     mapping(uint16 => uint) public minLiqIncentiveMultiplier_e18; // @inheritdoc ILiqIncentiveCalculator

24:     mapping(uint16 => uint) public minLiqIncentiveMultiplier_e18; // @inheritdoc ILiqIncentiveCalculator

60:         uint incentive_e18 = (ONE_E18 * ONE_E18) / _healthFactor_e18 - ONE_E18;

60:         uint incentive_e18 = (ONE_E18 * ONE_E18) / _healthFactor_e18 - ONE_E18;

60:         uint incentive_e18 = (ONE_E18 * ONE_E18) / _healthFactor_e18 - ONE_E18;

61:         incentive_e18 = (incentive_e18 * (modeLiqIncentiveMultiplier_e18[_mode] * maxTokenLiqIncentiveMultiplier_e18))

61:         incentive_e18 = (incentive_e18 * (modeLiqIncentiveMultiplier_e18[_mode] * maxTokenLiqIncentiveMultiplier_e18))

62:             / (ONE_E18 * ONE_E18);

62:             / (ONE_E18 * ONE_E18);

63:         multiplier_e18 = Math.min(ONE_E18 + incentive_e18, maxLiqIncentiveMultiplier_e18); // cap multiplier at max multiplier

63:         multiplier_e18 = Math.min(ONE_E18 + incentive_e18, maxLiqIncentiveMultiplier_e18); // cap multiplier at max multiplier

63:         multiplier_e18 = Math.min(ONE_E18 + incentive_e18, maxLiqIncentiveMultiplier_e18); // cap multiplier at max multiplier

64:         multiplier_e18 = Math.max(multiplier_e18, minLiqIncentiveMultiplier_e18[_mode]); // cap multiplier at min multiplier

64:         multiplier_e18 = Math.max(multiplier_e18, minLiqIncentiveMultiplier_e18[_mode]); // cap multiplier at min multiplier

```

```solidity
File: contracts/core/PosManager.sol

4: import '../common/library/InitErrors.sol';

4: import '../common/library/InitErrors.sol';

4: import '../common/library/InitErrors.sol';

5: import '../common/library/UncheckedIncrement.sol';

5: import '../common/library/UncheckedIncrement.sol';

5: import '../common/library/UncheckedIncrement.sol';

6: import {IPosManager} from '../interfaces/core/IPosManager.sol';

6: import {IPosManager} from '../interfaces/core/IPosManager.sol';

6: import {IPosManager} from '../interfaces/core/IPosManager.sol';

7: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

7: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

7: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

8: import {IBaseWrapLp} from '../interfaces/wrapper/IBaseWrapLp.sol';

8: import {IBaseWrapLp} from '../interfaces/wrapper/IBaseWrapLp.sol';

8: import {IBaseWrapLp} from '../interfaces/wrapper/IBaseWrapLp.sol';

9: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

9: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

9: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

9: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

10: import {SafeCast} from '@openzeppelin-contracts/utils/math/SafeCast.sol';

10: import {SafeCast} from '@openzeppelin-contracts/utils/math/SafeCast.sol';

10: import {SafeCast} from '@openzeppelin-contracts/utils/math/SafeCast.sol';

10: import {SafeCast} from '@openzeppelin-contracts/utils/math/SafeCast.sol';

11: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

11: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

11: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

11: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

11: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

13:     '@openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol';

13:     '@openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol';

13:     '@openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol';

13:     '@openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol';

13:     '@openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol';

13:     '@openzeppelin-contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol';

15:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

15:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

15:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

15:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

15:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

15:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

16: import {EnumerableSet} from '@openzeppelin-contracts/utils/structs/EnumerableSet.sol';

16: import {EnumerableSet} from '@openzeppelin-contracts/utils/structs/EnumerableSet.sol';

16: import {EnumerableSet} from '@openzeppelin-contracts/utils/structs/EnumerableSet.sol';

16: import {EnumerableSet} from '@openzeppelin-contracts/utils/structs/EnumerableSet.sol';

17: import {UnderACM} from '../common/UnderACM.sol';

17: import {UnderACM} from '../common/UnderACM.sol';

31:     mapping(address => uint) public nextNonces; // @inheritdoc IPosManager

31:     mapping(address => uint) public nextNonces; // @inheritdoc IPosManager

37:     uint8 public maxCollCount; // limit number of collateral to avoid out of gas

37:     uint8 public maxCollCount; // limit number of collateral to avoid out of gas

38:     mapping(uint => mapping(address => uint)) public pendingRewards; // @inheritdoc IPosManager

38:     mapping(uint => mapping(address => uint)) public pendingRewards; // @inheritdoc IPosManager

39:     mapping(address => mapping(uint => bool)) public isCollateralized; // @inheritdoc IPosManager

39:     mapping(address => mapping(uint => bool)) public isCollateralized; // @inheritdoc IPosManager

189:                 interest = (debtAmtCurrent - extraInfo.lastDebtAmt).toUint128();

191:             extraInfo.totalInterest += interest;

193:         uint newDebtShares = (currDebtShares.toInt256() + _deltaShares).toUint256();

214:         amtIn = newBalance - __collBalances[_pool];

219:             uint8 collCount = posCollInfo.collCount + 1;

224:         posCollInfo.collAmts[_pool] = posBalance + amtIn;

237:             uint8 collCount = posCollInfo.collCount + 1;

240:             ++posCollInfo.wLpCount;

240:             ++posCollInfo.wLpCount;

254:         uint newPosCollAmt = posCollInfo.collAmts[_pool] - _shares;

257:             --posCollInfo.collCount;

257:             --posCollInfo.collCount;

274:         uint newWLpAmt = IBaseWrapLp(_wLp).balanceOfLp(_tokenId) - _amt;

277:             --posCollInfo.collCount;

277:             --posCollInfo.collCount;

278:             --posCollInfo.wLpCount;

278:             --posCollInfo.wLpCount;

291:         uint nonce = nextNonces[_owner]++;

291:         uint nonce = nextNonces[_owner]++;

330:             pendingRewards[_posId][tokens[i]] += amts[i];

```

```solidity
File: contracts/helper/rebase_helper/BaseRebaseHelper.sol

4: import '../../interfaces/helper/rebase_helper/IRebaseHelper.sol';

4: import '../../interfaces/helper/rebase_helper/IRebaseHelper.sol';

4: import '../../interfaces/helper/rebase_helper/IRebaseHelper.sol';

4: import '../../interfaces/helper/rebase_helper/IRebaseHelper.sol';

4: import '../../interfaces/helper/rebase_helper/IRebaseHelper.sol';

```

```solidity
File: contracts/helper/rebase_helper/mUSDUSDYHelper.sol

4: import './BaseRebaseHelper.sol';

5: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

5: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

5: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

5: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

6: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

6: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

6: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

6: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

6: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

7: import {IMUSD} from '../../interfaces/helper/rebase_helper/IMUSD.sol';

7: import {IMUSD} from '../../interfaces/helper/rebase_helper/IMUSD.sol';

7: import {IMUSD} from '../../interfaces/helper/rebase_helper/IMUSD.sol';

7: import {IMUSD} from '../../interfaces/helper/rebase_helper/IMUSD.sol';

7: import {IMUSD} from '../../interfaces/helper/rebase_helper/IMUSD.sol';

```

```solidity
File: contracts/helper/swap_helper/MoeSwapHelper.sol

4: import {IBaseSwapHelper} from '../../interfaces/helper/swap_helper/IBaseSwapHelper.sol';

4: import {IBaseSwapHelper} from '../../interfaces/helper/swap_helper/IBaseSwapHelper.sol';

4: import {IBaseSwapHelper} from '../../interfaces/helper/swap_helper/IBaseSwapHelper.sol';

4: import {IBaseSwapHelper} from '../../interfaces/helper/swap_helper/IBaseSwapHelper.sol';

4: import {IBaseSwapHelper} from '../../interfaces/helper/swap_helper/IBaseSwapHelper.sol';

5: import {SwapInfo, SwapType} from '../../interfaces/hook/IMarginTradingHook.sol';

5: import {SwapInfo, SwapType} from '../../interfaces/hook/IMarginTradingHook.sol';

5: import {SwapInfo, SwapType} from '../../interfaces/hook/IMarginTradingHook.sol';

5: import {SwapInfo, SwapType} from '../../interfaces/hook/IMarginTradingHook.sol';

6: import {IMoeRouter} from '../../interfaces/common/moe/IMoeRouter.sol';

6: import {IMoeRouter} from '../../interfaces/common/moe/IMoeRouter.sol';

6: import {IMoeRouter} from '../../interfaces/common/moe/IMoeRouter.sol';

6: import {IMoeRouter} from '../../interfaces/common/moe/IMoeRouter.sol';

6: import {IMoeRouter} from '../../interfaces/common/moe/IMoeRouter.sol';

8: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

8: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

8: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

8: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

9: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

9: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

9: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

9: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

9: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

```

```solidity
File: contracts/hook/BaseMappingIdHook.sol

4: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

4: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

4: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

4: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

5: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

5: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

5: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

5: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

5: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

7:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

7:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

7:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

7:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

7:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

7:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

```

```solidity
File: contracts/hook/MarginTradingHook.sol

4: import '../common/library/InitErrors.sol';

4: import '../common/library/InitErrors.sol';

4: import '../common/library/InitErrors.sol';

5: import {UnderACM} from '../common/UnderACM.sol';

5: import {UnderACM} from '../common/UnderACM.sol';

6: import {BaseMappingIdHook} from './BaseMappingIdHook.sol';

16: } from '../interfaces/hook/IMarginTradingHook.sol';

16: } from '../interfaces/hook/IMarginTradingHook.sol';

16: } from '../interfaces/hook/IMarginTradingHook.sol';

17: import {IWNative} from '../interfaces/common/IWNative.sol';

17: import {IWNative} from '../interfaces/common/IWNative.sol';

17: import {IWNative} from '../interfaces/common/IWNative.sol';

18: import {IInitCore} from '../interfaces/core/IInitCore.sol';

18: import {IInitCore} from '../interfaces/core/IInitCore.sol';

18: import {IInitCore} from '../interfaces/core/IInitCore.sol';

19: import {ICallbackReceiver} from '../interfaces/receiver/ICallbackReceiver.sol';

19: import {ICallbackReceiver} from '../interfaces/receiver/ICallbackReceiver.sol';

19: import {ICallbackReceiver} from '../interfaces/receiver/ICallbackReceiver.sol';

20: import {IMulticall} from '../interfaces/common/IMulticall.sol';

20: import {IMulticall} from '../interfaces/common/IMulticall.sol';

20: import {IMulticall} from '../interfaces/common/IMulticall.sol';

21: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

21: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

21: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

22: import {IPosManager} from '../interfaces/core/IPosManager.sol';

22: import {IPosManager} from '../interfaces/core/IPosManager.sol';

22: import {IPosManager} from '../interfaces/core/IPosManager.sol';

23: import {IInitOracle} from '../interfaces/oracle/IInitOracle.sol';

23: import {IInitOracle} from '../interfaces/oracle/IInitOracle.sol';

23: import {IInitOracle} from '../interfaces/oracle/IInitOracle.sol';

24: import {IBaseSwapHelper} from '../interfaces/helper/swap_helper/IBaseSwapHelper.sol';

24: import {IBaseSwapHelper} from '../interfaces/helper/swap_helper/IBaseSwapHelper.sol';

24: import {IBaseSwapHelper} from '../interfaces/helper/swap_helper/IBaseSwapHelper.sol';

24: import {IBaseSwapHelper} from '../interfaces/helper/swap_helper/IBaseSwapHelper.sol';

26: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

26: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

26: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

26: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

27: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

27: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

27: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

27: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

27: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

28: import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';

28: import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';

28: import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';

28: import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';

107:         posId = ++lastPosIds[msg.sender];

107:         posId = ++lastPosIds[msg.sender];

409:         IERC20(swapInfo.tokenIn).safeTransfer(swapHelper, amtIn); // transfer all token in to swap helper

409:         IERC20(swapInfo.tokenIn).safeTransfer(swapHelper, amtIn); // transfer all token in to swap helper

423:                 amtSwapped -= IERC20(swapInfo.tokenIn).balanceOf(address(this));

478:         orderId = ++lastOrderId;

478:         orderId = ++lastOrderId;

485:         _require(_collAmt <= collAmt, Errors.INPUT_TOO_HIGH); // check specified coll amt is feasible

485:         _require(_collAmt <= collAmt, Errors.INPUT_TOO_HIGH); // check specified coll amt is feasible

544:                 amtOut = collTokenAmt - repayAmt * ONE_E36 / _order.limitPrice_e36;

544:                 amtOut = collTokenAmt - repayAmt * ONE_E36 / _order.limitPrice_e36;

544:                 amtOut = collTokenAmt - repayAmt * ONE_E36 / _order.limitPrice_e36;

549:                 amtOut = collTokenAmt - (repayAmt * _order.limitPrice_e36 / ONE_E36);

549:                 amtOut = collTokenAmt - (repayAmt * _order.limitPrice_e36 / ONE_E36);

549:                 amtOut = collTokenAmt - (repayAmt * _order.limitPrice_e36 / ONE_E36);

556:                 amtOut = (collTokenAmt * _order.limitPrice_e36).ceilDiv(ONE_E36) - repayAmt;

556:                 amtOut = (collTokenAmt * _order.limitPrice_e36).ceilDiv(ONE_E36) - repayAmt;

561:                 amtOut = (collTokenAmt * ONE_E36).ceilDiv(_order.limitPrice_e36) - repayAmt;

561:                 amtOut = (collTokenAmt * ONE_E36).ceilDiv(_order.limitPrice_e36) - repayAmt;

597:         repayShares = totalDebtShares * _order.collAmt / totalCollAmt;

597:         repayShares = totalDebtShares * _order.collAmt / totalCollAmt;

609:             amtToTransfer = _amt > msg.value ? amtToTransfer - msg.value : 0;

```

```solidity
File: contracts/hook/MoneyMarketHook.sol

4: import '../common/library/InitErrors.sol';

4: import '../common/library/InitErrors.sol';

4: import '../common/library/InitErrors.sol';

5: import '../common/library/UncheckedIncrement.sol';

5: import '../common/library/UncheckedIncrement.sol';

5: import '../common/library/UncheckedIncrement.sol';

6: import {UnderACM} from '../common/UnderACM.sol';

6: import {UnderACM} from '../common/UnderACM.sol';

7: import {IInitCore} from '../interfaces/core/IInitCore.sol';

7: import {IInitCore} from '../interfaces/core/IInitCore.sol';

7: import {IInitCore} from '../interfaces/core/IInitCore.sol';

8: import {IMulticall} from '../interfaces/common/IMulticall.sol';

8: import {IMulticall} from '../interfaces/common/IMulticall.sol';

8: import {IMulticall} from '../interfaces/common/IMulticall.sol';

9: import {IPosManager} from '../interfaces/core/IPosManager.sol';

9: import {IPosManager} from '../interfaces/core/IPosManager.sol';

9: import {IPosManager} from '../interfaces/core/IPosManager.sol';

10: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

10: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

10: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

11: import {IWNative} from '../interfaces/common/IWNative.sol';

11: import {IWNative} from '../interfaces/common/IWNative.sol';

11: import {IWNative} from '../interfaces/common/IWNative.sol';

12: import {IRebaseHelper} from '../interfaces/helper/rebase_helper/IRebaseHelper.sol';

12: import {IRebaseHelper} from '../interfaces/helper/rebase_helper/IRebaseHelper.sol';

12: import {IRebaseHelper} from '../interfaces/helper/rebase_helper/IRebaseHelper.sol';

12: import {IRebaseHelper} from '../interfaces/helper/rebase_helper/IRebaseHelper.sol';

13: import {IMoneyMarketHook} from '../interfaces/hook/IMoneyMarketHook.sol';

13: import {IMoneyMarketHook} from '../interfaces/hook/IMoneyMarketHook.sol';

13: import {IMoneyMarketHook} from '../interfaces/hook/IMoneyMarketHook.sol';

15: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

15: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

15: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

15: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

16: import {IERC721} from '@openzeppelin-contracts/token/ERC721/IERC721.sol';

16: import {IERC721} from '@openzeppelin-contracts/token/ERC721/IERC721.sol';

16: import {IERC721} from '@openzeppelin-contracts/token/ERC721/IERC721.sol';

16: import {IERC721} from '@openzeppelin-contracts/token/ERC721/IERC721.sol';

17: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

17: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

17: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

17: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

17: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

19:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

19:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

19:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

19:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

19:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

19:     '@openzeppelin-contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol';

20: import {ReentrancyGuardUpgradeable} from '@openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';

20: import {ReentrancyGuardUpgradeable} from '@openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';

20: import {ReentrancyGuardUpgradeable} from '@openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';

20: import {ReentrancyGuardUpgradeable} from '@openzeppelin-contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';

108:         posId = ++lastPosIds[msg.sender];

108:         posId = ++lastPosIds[msg.sender];

147:             uint dataLength = _params.repayParams.length + (2 * _params.withdrawParams.length) + (changeMode ? 1 : 0)

147:             uint dataLength = _params.repayParams.length + (2 * _params.withdrawParams.length) + (changeMode ? 1 : 0)

147:             uint dataLength = _params.repayParams.length + (2 * _params.withdrawParams.length) + (changeMode ? 1 : 0)

148:                 + _params.borrowParams.length + (2 * _params.depositParams.length);

148:                 + _params.borrowParams.length + (2 * _params.depositParams.length);

148:                 + _params.borrowParams.length + (2 * _params.depositParams.length);

188:                 repayAmt = repayAmt > msg.value ? repayAmt - msg.value : 0;

```

```solidity
File: contracts/lending_pool/DoubleSlopeIRM.sol

4: import {IIRM} from '../interfaces/lending_pool/IIRM.sol';

4: import {IIRM} from '../interfaces/lending_pool/IIRM.sol';

4: import {IIRM} from '../interfaces/lending_pool/IIRM.sol';

5: import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';

5: import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';

5: import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';

5: import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';

12:     uint public immutable BASE_BORR_RATE_E18; // rate per second

12:     uint public immutable BASE_BORR_RATE_E18; // rate per second

13:     uint public immutable BORR_RATE_MULTIPLIER_E18; // m1

13:     uint public immutable BORR_RATE_MULTIPLIER_E18; // m1

14:     uint public immutable JUMP_UTIL_E18; // utilization at which the BORROW_RATE_M2 is applied

14:     uint public immutable JUMP_UTIL_E18; // utilization at which the BORROW_RATE_M2 is applied

15:     uint public immutable JUMP_MULTIPLIER_E18; // m2

15:     uint public immutable JUMP_MULTIPLIER_E18; // m2

35:         uint totalAsset = _cash + _debt;

36:         uint util_e18 = totalAsset == 0 ? 0 : (_debt * ONE_E18) / totalAsset;

36:         uint util_e18 = totalAsset == 0 ? 0 : (_debt * ONE_E18) / totalAsset;

37:         borrow_rate_e18 = BASE_BORR_RATE_E18 + (Math.min(util_e18, JUMP_UTIL_E18) * BORR_RATE_MULTIPLIER_E18) / ONE_E18;

37:         borrow_rate_e18 = BASE_BORR_RATE_E18 + (Math.min(util_e18, JUMP_UTIL_E18) * BORR_RATE_MULTIPLIER_E18) / ONE_E18;

37:         borrow_rate_e18 = BASE_BORR_RATE_E18 + (Math.min(util_e18, JUMP_UTIL_E18) * BORR_RATE_MULTIPLIER_E18) / ONE_E18;

39:             borrow_rate_e18 += ((util_e18 - JUMP_UTIL_E18) * JUMP_MULTIPLIER_E18) / ONE_E18;

39:             borrow_rate_e18 += ((util_e18 - JUMP_UTIL_E18) * JUMP_MULTIPLIER_E18) / ONE_E18;

39:             borrow_rate_e18 += ((util_e18 - JUMP_UTIL_E18) * JUMP_MULTIPLIER_E18) / ONE_E18;

39:             borrow_rate_e18 += ((util_e18 - JUMP_UTIL_E18) * JUMP_MULTIPLIER_E18) / ONE_E18;

```

```solidity
File: contracts/lending_pool/LendingPool.sol

4: import '../common/library/InitErrors.sol';

4: import '../common/library/InitErrors.sol';

4: import '../common/library/InitErrors.sol';

5: import {UnderACM} from '../common/UnderACM.sol';

5: import {UnderACM} from '../common/UnderACM.sol';

6: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

6: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

6: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

7: import {IIRM} from '../interfaces/lending_pool/IIRM.sol';

7: import {IIRM} from '../interfaces/lending_pool/IIRM.sol';

7: import {IIRM} from '../interfaces/lending_pool/IIRM.sol';

9: import {ERC20Upgradeable} from '@openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';

9: import {ERC20Upgradeable} from '@openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';

9: import {ERC20Upgradeable} from '@openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';

9: import {ERC20Upgradeable} from '@openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';

9: import {ERC20Upgradeable} from '@openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';

10: import {IERC20Metadata} from '@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol';

10: import {IERC20Metadata} from '@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol';

10: import {IERC20Metadata} from '@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol';

10: import {IERC20Metadata} from '@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol';

10: import {IERC20Metadata} from '@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol';

11: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

11: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

11: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

11: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

11: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

12: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

12: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

12: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

12: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

13: import {MathUpgradeable} from '@openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol';

13: import {MathUpgradeable} from '@openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol';

13: import {MathUpgradeable} from '@openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol';

13: import {MathUpgradeable} from '@openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol';

13: import {MathUpgradeable} from '@openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol';

22:     uint private constant VIRTUAL_SHARES = 10 ** VIRTUAL_SHARE_DECIMALS;

22:     uint private constant VIRTUAL_SHARES = 10 ** VIRTUAL_SHARE_DECIMALS;

31:     address public underlyingToken; // underlying tokens

31:     address public underlyingToken; // underlying tokens

32:     uint public cash; // total cash

32:     uint public cash; // total cash

33:     uint public totalDebt; // total debt

33:     uint public totalDebt; // total debt

34:     uint public totalDebtShares; // total debt shares

34:     uint public totalDebtShares; // total debt shares

35:     address public irm; // interest rate model

35:     address public irm; // interest rate model

36:     uint public lastAccruedTime; // last accrued timestamp

36:     uint public lastAccruedTime; // last accrued timestamp

37:     uint public reserveFactor_e18; // reserve factor

37:     uint public reserveFactor_e18; // reserve factor

38:     address public treasury; // treasury address

38:     address public treasury; // treasury address

97:         return IERC20Metadata(underlyingToken).decimals() + VIRTUAL_SHARE_DECIMALS;

104:         uint amt = newCash - _cash;

105:         shares = _toShares(amt, _cash + totalDebt, totalSupply());

116:         amt = _toAmt(sharesToBurn, _cash + totalDebt, totalSupply());

119:             cash = _cash - amt;

130:         totalDebtShares += shares;

131:         totalDebt = _totalDebt + _amt;

133:             cash -= _amt;

144:         _require(amt <= IERC20(underlyingToken).balanceOf(address(this)) - _cash, Errors.INVALID_AMOUNT_TO_REPAY);

145:         totalDebtShares = _totalDebtShares - _shares;

146:         totalDebt = _totalDebt > amt ? _totalDebt - amt : 0;

147:         cash = _cash + amt;

157:             uint accruedInterest = (borrowRate_e18 * (block.timestamp - _lastAccruedTime) * _totalDebt) / ONE_E18;

157:             uint accruedInterest = (borrowRate_e18 * (block.timestamp - _lastAccruedTime) * _totalDebt) / ONE_E18;

157:             uint accruedInterest = (borrowRate_e18 * (block.timestamp - _lastAccruedTime) * _totalDebt) / ONE_E18;

157:             uint accruedInterest = (borrowRate_e18 * (block.timestamp - _lastAccruedTime) * _totalDebt) / ONE_E18;

158:             uint reserve = (accruedInterest * reserveFactor_e18) / ONE_E18;

158:             uint reserve = (accruedInterest * reserveFactor_e18) / ONE_E18;

160:                 _mint(treasury, _toShares(reserve, _cash + _totalDebt + accruedInterest - reserve, totalSupply()));

160:                 _mint(treasury, _toShares(reserve, _cash + _totalDebt + accruedInterest - reserve, totalSupply()));

160:                 _mint(treasury, _toShares(reserve, _cash + _totalDebt + accruedInterest - reserve, totalSupply()));

162:             totalDebt = _totalDebt + accruedInterest;

213:         supplyRate_e18 = _cash + _totalDebt > 0

214:             ? (borrowRate_e18 * (ONE_E18 - reserveFactor_e18) * _totalDebt) / ((_cash + _totalDebt) * ONE_E18)

214:             ? (borrowRate_e18 * (ONE_E18 - reserveFactor_e18) * _totalDebt) / ((_cash + _totalDebt) * ONE_E18)

214:             ? (borrowRate_e18 * (ONE_E18 - reserveFactor_e18) * _totalDebt) / ((_cash + _totalDebt) * ONE_E18)

214:             ? (borrowRate_e18 * (ONE_E18 - reserveFactor_e18) * _totalDebt) / ((_cash + _totalDebt) * ONE_E18)

214:             ? (borrowRate_e18 * (ONE_E18 - reserveFactor_e18) * _totalDebt) / ((_cash + _totalDebt) * ONE_E18)

214:             ? (borrowRate_e18 * (ONE_E18 - reserveFactor_e18) * _totalDebt) / ((_cash + _totalDebt) * ONE_E18)

225:         return cash + totalDebt;

254:         return _amt.mulDiv(_totalShares + VIRTUAL_SHARES, _totalAssets + VIRTUAL_ASSETS);

254:         return _amt.mulDiv(_totalShares + VIRTUAL_SHARES, _totalAssets + VIRTUAL_ASSETS);

264:         return _shares.mulDiv(_totalAssets + VIRTUAL_ASSETS, _totalShares + VIRTUAL_SHARES);

264:         return _shares.mulDiv(_totalAssets + VIRTUAL_ASSETS, _totalShares + VIRTUAL_SHARES);

```

```solidity
File: contracts/oracle/Api3OracleReader.sol

4: import {SafeCast} from '@openzeppelin-contracts/utils/math/SafeCast.sol';

4: import {SafeCast} from '@openzeppelin-contracts/utils/math/SafeCast.sol';

4: import {SafeCast} from '@openzeppelin-contracts/utils/math/SafeCast.sol';

4: import {SafeCast} from '@openzeppelin-contracts/utils/math/SafeCast.sol';

5: import {IERC20Metadata} from '@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol';

5: import {IERC20Metadata} from '@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol';

5: import {IERC20Metadata} from '@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol';

5: import {IERC20Metadata} from '@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol';

5: import {IERC20Metadata} from '@openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol';

6: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

6: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

6: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

6: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

6: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

8: import '../common/library/InitErrors.sol';

8: import '../common/library/InitErrors.sol';

8: import '../common/library/InitErrors.sol';

9: import '../common/library/UncheckedIncrement.sol';

9: import '../common/library/UncheckedIncrement.sol';

9: import '../common/library/UncheckedIncrement.sol';

10: import {UnderACM} from '../common/UnderACM.sol';

10: import {UnderACM} from '../common/UnderACM.sol';

12: import {IApi3OracleReader, IBaseOracle} from '../interfaces/oracle/api3/IApi3OracleReader.sol';

12: import {IApi3OracleReader, IBaseOracle} from '../interfaces/oracle/api3/IApi3OracleReader.sol';

12: import {IApi3OracleReader, IBaseOracle} from '../interfaces/oracle/api3/IApi3OracleReader.sol';

12: import {IApi3OracleReader, IBaseOracle} from '../interfaces/oracle/api3/IApi3OracleReader.sol';

13: import {IApi3ServerV1} from '../interfaces/oracle/api3/IApi3ServerV1.sol';

13: import {IApi3ServerV1} from '../interfaces/oracle/api3/IApi3ServerV1.sol';

13: import {IApi3ServerV1} from '../interfaces/oracle/api3/IApi3ServerV1.sol';

13: import {IApi3ServerV1} from '../interfaces/oracle/api3/IApi3ServerV1.sol';

24:     address public api3ServerV1; // @inheritdoc IApi3OracleReader

24:     address public api3ServerV1; // @inheritdoc IApi3OracleReader

25:     mapping(address => DataFeedInfo) public dataFeedInfos; // @inheritdoc IApi3OracleReader

25:     mapping(address => DataFeedInfo) public dataFeedInfos; // @inheritdoc IApi3OracleReader

88:             _require(block.timestamp - timestamp <= dataFeedInfo.maxStaleTime, Errors.MAX_STALETIME_EXCEEDED);

92:         price_e36 = (price.toUint256() * ONE_E18) / 10 ** decimals;

92:         price_e36 = (price.toUint256() * ONE_E18) / 10 ** decimals;

92:         price_e36 = (price.toUint256() * ONE_E18) / 10 ** decimals;

92:         price_e36 = (price.toUint256() * ONE_E18) / 10 ** decimals;

```

```solidity
File: contracts/oracle/InitOracle.sol

4: import '../common/library/InitErrors.sol';

4: import '../common/library/InitErrors.sol';

4: import '../common/library/InitErrors.sol';

5: import '../common/library/UncheckedIncrement.sol';

5: import '../common/library/UncheckedIncrement.sol';

5: import '../common/library/UncheckedIncrement.sol';

7: import {UnderACM} from '../common/UnderACM.sol';

7: import {UnderACM} from '../common/UnderACM.sol';

9: import {IInitOracle, IBaseOracle} from '../interfaces/oracle/IInitOracle.sol';

9: import {IInitOracle, IBaseOracle} from '../interfaces/oracle/IInitOracle.sol';

9: import {IInitOracle, IBaseOracle} from '../interfaces/oracle/IInitOracle.sol';

10: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

10: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

10: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

10: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

10: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

20:     mapping(address => address) public primarySources; // @inheritdoc IInitOracle

20:     mapping(address => address) public primarySources; // @inheritdoc IInitOracle

21:     mapping(address => address) public secondarySources; // @inheritdoc IInitOracle

21:     mapping(address => address) public secondarySources; // @inheritdoc IInitOracle

22:     mapping(address => uint) public maxPriceDeviations_e18; // @inheritdoc IInitOracle

22:     mapping(address => uint) public maxPriceDeviations_e18; // @inheritdoc IInitOracle

79:                 (maxPrice_e36 * ONE_E18) / minPrice_e36 <= maxPriceDeviations_e18[_token], Errors.TOO_MUCH_DEVIATION

79:                 (maxPrice_e36 * ONE_E18) / minPrice_e36 <= maxPriceDeviations_e18[_token], Errors.TOO_MUCH_DEVIATION

```

```solidity
File: contracts/risk_manager/RiskManager.sol

4: import {IRiskManager} from '../interfaces/risk_manager/IRiskManager.sol';

4: import {IRiskManager} from '../interfaces/risk_manager/IRiskManager.sol';

4: import {IRiskManager} from '../interfaces/risk_manager/IRiskManager.sol';

5: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

5: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

5: import {ILendingPool} from '../interfaces/lending_pool/ILendingPool.sol';

6: import '../common/library/InitErrors.sol';

6: import '../common/library/InitErrors.sol';

6: import '../common/library/InitErrors.sol';

7: import '../common/library/UncheckedIncrement.sol';

7: import '../common/library/UncheckedIncrement.sol';

7: import '../common/library/UncheckedIncrement.sol';

8: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

8: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

8: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

8: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

8: import {Initializable} from '@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol';

9: import {SafeCast} from '@openzeppelin-contracts/utils/math/SafeCast.sol';

9: import {SafeCast} from '@openzeppelin-contracts/utils/math/SafeCast.sol';

9: import {SafeCast} from '@openzeppelin-contracts/utils/math/SafeCast.sol';

9: import {SafeCast} from '@openzeppelin-contracts/utils/math/SafeCast.sol';

10: import {UnderACM} from '../common/UnderACM.sol';

10: import {UnderACM} from '../common/UnderACM.sol';

22:     address public immutable CORE; // core address

22:     address public immutable CORE; // core address

72:         uint newDebtShares = (debtCeilingInfo.debtShares.toInt256() + _deltaShares).toUint256();

```

```solidity
File: contracts/wrapper/WLpMoeMasterChef.sol

4: import '../common/library/InitErrors.sol';

4: import '../common/library/InitErrors.sol';

4: import '../common/library/InitErrors.sol';

5: import '../common/library/UncheckedIncrement.sol';

5: import '../common/library/UncheckedIncrement.sol';

5: import '../common/library/UncheckedIncrement.sol';

6: import {IWrapLpERC20Upgradeable} from '../interfaces/wrapper/IWrapLpERC20Upgradeable.sol';

6: import {IWrapLpERC20Upgradeable} from '../interfaces/wrapper/IWrapLpERC20Upgradeable.sol';

6: import {IWrapLpERC20Upgradeable} from '../interfaces/wrapper/IWrapLpERC20Upgradeable.sol';

7: import {IMasterChefRewarder} from '../interfaces/wrapper/moe/IMasterChefRewarder.sol';

7: import {IMasterChefRewarder} from '../interfaces/wrapper/moe/IMasterChefRewarder.sol';

7: import {IMasterChefRewarder} from '../interfaces/wrapper/moe/IMasterChefRewarder.sol';

7: import {IMasterChefRewarder} from '../interfaces/wrapper/moe/IMasterChefRewarder.sol';

8: import {IMasterChef} from '../interfaces/wrapper/moe/IMasterChef.sol';

8: import {IMasterChef} from '../interfaces/wrapper/moe/IMasterChef.sol';

8: import {IMasterChef} from '../interfaces/wrapper/moe/IMasterChef.sol';

8: import {IMasterChef} from '../interfaces/wrapper/moe/IMasterChef.sol';

9: import {IMoePair} from '../interfaces/wrapper/moe/IMoePair.sol';

9: import {IMoePair} from '../interfaces/wrapper/moe/IMoePair.sol';

9: import {IMoePair} from '../interfaces/wrapper/moe/IMoePair.sol';

9: import {IMoePair} from '../interfaces/wrapper/moe/IMoePair.sol';

10: import {IMoeFactory} from '../interfaces/wrapper/moe/IMoeFactory.sol';

10: import {IMoeFactory} from '../interfaces/wrapper/moe/IMoeFactory.sol';

10: import {IMoeFactory} from '../interfaces/wrapper/moe/IMoeFactory.sol';

10: import {IMoeFactory} from '../interfaces/wrapper/moe/IMoeFactory.sol';

11: import {IInitOracle} from '../interfaces/oracle/IInitOracle.sol';

11: import {IInitOracle} from '../interfaces/oracle/IInitOracle.sol';

11: import {IInitOracle} from '../interfaces/oracle/IInitOracle.sol';

12: import {IWNative} from '../interfaces/common/IWNative.sol';

12: import {IWNative} from '../interfaces/common/IWNative.sol';

12: import {IWNative} from '../interfaces/common/IWNative.sol';

14: import {ERC721} from '@openzeppelin-contracts/token/ERC721/ERC721.sol';

14: import {ERC721} from '@openzeppelin-contracts/token/ERC721/ERC721.sol';

14: import {ERC721} from '@openzeppelin-contracts/token/ERC721/ERC721.sol';

14: import {ERC721} from '@openzeppelin-contracts/token/ERC721/ERC721.sol';

15: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

15: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

15: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

15: import {IERC20} from '@openzeppelin-contracts/token/ERC20/IERC20.sol';

16: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

16: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

16: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

16: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

16: import {SafeERC20} from '@openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol';

17: import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';

17: import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';

17: import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';

17: import {Math} from '@openzeppelin-contracts/utils/math/Math.sol';

18: import {EnumerableSet} from '@openzeppelin-contracts/utils/structs/EnumerableSet.sol';

18: import {EnumerableSet} from '@openzeppelin-contracts/utils/structs/EnumerableSet.sol';

18: import {EnumerableSet} from '@openzeppelin-contracts/utils/structs/EnumerableSet.sol';

18: import {EnumerableSet} from '@openzeppelin-contracts/utils/structs/EnumerableSet.sol';

19: import {ERC721Upgradeable} from '@openzeppelin-contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';

19: import {ERC721Upgradeable} from '@openzeppelin-contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';

19: import {ERC721Upgradeable} from '@openzeppelin-contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';

19: import {ERC721Upgradeable} from '@openzeppelin-contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';

19: import {ERC721Upgradeable} from '@openzeppelin-contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';

39:     uint public lastId; // last wLp id

39:     uint public lastId; // last wLp id

41:     mapping(uint => address) public lps; // lp token address for each wLp id

41:     mapping(uint => address) public lps; // lp token address for each wLp id

43:     mapping(uint => uint) private __lpBalances; // amount of lp token for each wLp id

43:     mapping(uint => uint) private __lpBalances; // amount of lp token for each wLp id

45:     mapping(uint => uint) public pids; // masterchef pool id for each wLp id

45:     mapping(uint => uint) public pids; // masterchef pool id for each wLp id

47:     mapping(uint => EnumerableSet.AddressSet) private __rewardTokens; // reward tokens for each wLp id

47:     mapping(uint => EnumerableSet.AddressSet) private __rewardTokens; // reward tokens for each wLp id

49:     mapping(uint => mapping(address => uint)) public idAccRewardPerShares_e18; // acc reward per share for each token in each wLp id

49:     mapping(uint => mapping(address => uint)) public idAccRewardPerShares_e18; // acc reward per share for each token in each wLp id

51:     mapping(uint => mapping(address => uint)) public pidAccRewardPerShares_e18; // acc reward per share for each reward token in masterchef pid

51:     mapping(uint => mapping(address => uint)) public pidAccRewardPerShares_e18; // acc reward per share for each reward token in masterchef pid

81:                 _pidAccRewardPerShares_e18[i] +=

82:                     ((IERC20(rewardToken).balanceOf(address(this)) - rewardBeforeAmts[i]) * ONE_E18) / lpSupply;

82:                     ((IERC20(rewardToken).balanceOf(address(this)) - rewardBeforeAmts[i]) * ONE_E18) / lpSupply;

82:                     ((IERC20(rewardToken).balanceOf(address(this)) - rewardBeforeAmts[i]) * ONE_E18) / lpSupply;

121:         id = ++lastId;

121:         id = ++lastId;

150:         __lpBalances[_id] = lpBalance - _amt;

208:             price = 2 * (r0 * prices_e36[0]).sqrt() * (r1 * prices_e36[1]).sqrt() / totalSupply;

208:             price = 2 * (r0 * prices_e36[0]).sqrt() * (r1 * prices_e36[1]).sqrt() / totalSupply;

208:             price = 2 * (r0 * prices_e36[0]).sqrt() * (r1 * prices_e36[1]).sqrt() / totalSupply;

208:             price = 2 * (r0 * prices_e36[0]).sqrt() * (r1 * prices_e36[1]).sqrt() / totalSupply;

208:             price = 2 * (r0 * prices_e36[0]).sqrt() * (r1 * prices_e36[1]).sqrt() / totalSupply;

211:             price = 2 * (kLast.mulDiv(prices_e36[0].mulDiv(prices_e36[1], totalSupply), totalSupply)).sqrt();

232:                 tokens = new address[](numToken + 1);

250:                     pidAccRewardPerShares_e18[pid][MOE] + moeRewards[0] * ONE_E18 / lpSupply;

250:                     pidAccRewardPerShares_e18[pid][MOE] + moeRewards[0] * ONE_E18 / lpSupply;

250:                     pidAccRewardPerShares_e18[pid][MOE] + moeRewards[0] * ONE_E18 / lpSupply;

253:                     pidAccRewardPerShares_e18[pid][extraToken] + extraRewards[0] * ONE_E18 / lpSupply;

253:                     pidAccRewardPerShares_e18[pid][extraToken] + extraRewards[0] * ONE_E18 / lpSupply;

253:                     pidAccRewardPerShares_e18[pid][extraToken] + extraRewards[0] * ONE_E18 / lpSupply;

263:             amts[i] = (currentAccRewardPerShares_e18[i] - idAccRewardPerShares_e18[_id][tokens[i]]) * __lpBalances[_id]

263:             amts[i] = (currentAccRewardPerShares_e18[i] - idAccRewardPerShares_e18[_id][tokens[i]]) * __lpBalances[_id]

264:                 / ONE_E18;

319:             uint amt = (pidAccRewardPerShares_e18[pid][rewardToken] - idAccRewardPerShares_e18[_id][rewardToken]) * _amt

319:             uint amt = (pidAccRewardPerShares_e18[pid][rewardToken] - idAccRewardPerShares_e18[_id][rewardToken]) * _amt

320:                 / ONE_E18;

```

### <a name="GAS-4"></a>[GAS-4] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (34)*:
```solidity
File: contracts/core/Config.sol

96:     function setPoolConfig(address _pool, PoolConfig calldata _config) external onlyGuardian {

136:     function setModeStatus(uint16 _mode, ModeStatus calldata _status) external onlyGuardian {

143:     function setMaxHealthAfterLiq_e18(uint16 _mode, uint64 _maxHealthAfterLiq_e18) external onlyGuardian {

151:     function setMaxCollWLpCount(uint16 _mode, uint8 _maxCollWLpCount) external onlyGuardian {

158:     function setWhitelistedWLps(address[] calldata _wLps, bool _status) external onlyGovernor {

```

```solidity
File: contracts/core/InitCore.sol

221:     function collateralize(uint _posId, address _pool) public virtual onlyAuthorized(_posId) nonReentrant {

414:     function setConfig(address _config) external onlyGovernor {

419:     function setOracle(address _oracle) external onlyGovernor {

424:     function setLiqIncentiveCalculator(address _liqIncentiveCalculator) external onlyGuardian {

429:     function setRiskManager(address _riskManager) external onlyGuardian {

```

```solidity
File: contracts/core/LiqIncentiveCalculator.sol

94:     function setMaxLiqIncentiveMultiplier_e18(uint _maxLiqIncentiveMultiplier_e18) external onlyGovernor {

```

```solidity
File: contracts/core/PosManager.sol

181:     function updatePosDebtShares(uint _posId, address _pool, int _deltaShares) external onlyCore {

206:     function updatePosMode(uint _posId, uint16 _mode) external onlyCore {

211:     function addCollateral(uint _posId, address _pool) external onlyCore returns (uint amtIn) {

229:     function addCollateralWLp(uint _posId, address _wLp, uint _tokenId) external onlyCore returns (uint amtIn) {

290:     function createPos(address _owner, uint16 _mode, address _viewer) external onlyCore returns (uint posId) {

340:     function setMaxCollCount(uint8 _maxCollCount) external onlyGuardian {

346:     function setPosViewer(uint _posId, address _viewer) external onlyAuthorized(_posId) {

```

```solidity
File: contracts/hook/MarginTradingHook.sol

431:     function setQuoteAsset(address _tokenA, address _tokenB, address _quoteAsset) external onlyGovernor {

```

```solidity
File: contracts/hook/MoneyMarketHook.sol

114:     function setWhitelistedHelpers(address[] calldata _helpers, bool _status) external onlyGuardian {

```

```solidity
File: contracts/lending_pool/LendingPool.sol

101:     function mint(address _receiver) external onlyCore accrue returns (uint shares) {

112:     function burn(address _receiver) external onlyCore accrue returns (uint amt) {

126:     function borrow(address _receiver, uint _amt) external onlyCore accrue returns (uint shares) {

139:     function repay(uint _shares) external onlyCore accrue returns (uint amt) {

229:     function setIrm(address _irm) external accrue onlyGuardian {

235:     function setReserveFactor_e18(uint _reserveFactor_e18) external accrue onlyGuardian {

242:     function setTreasury(address _treasury) external accrue onlyGovernor {

```

```solidity
File: contracts/oracle/Api3OracleReader.sol

48:     function setDataFeedIds(address[] calldata _tokens, bytes32[] calldata _dataFeedIds) external onlyGovernor {

58:     function setApi3ServerV1(address _api3ServerV1) external onlyGovernor {

64:     function setMaxStaleTimes(address[] calldata _tokens, uint[] calldata _maxStaleTimes) external onlyGovernor {

```

```solidity
File: contracts/oracle/InitOracle.sol

94:     function setPrimarySources(address[] calldata _tokens, address[] calldata _sources) external onlyGovernor {

103:     function setSecondarySources(address[] calldata _tokens, address[] calldata _sources) external onlyGovernor {

```

```solidity
File: contracts/risk_manager/RiskManager.sol

70:     function updateModeDebtShares(uint16 _mode, address _pool, int _deltaShares) external onlyCore {

```

```solidity
File: contracts/wrapper/WLpMoeMasterChef.sol

145:     function unwrap(uint _id, uint _amt, address _to) external onlyOwner(_id) returns (bytes memory amtOut) {

```

### <a name="GAS-5"></a>[GAS-5] `++i` costs less gas than `i++`, especially when it's used in `for`-loops (`--i`/`i--` too)
*Saves 5 gas per loop*

*Instances (1)*:
```solidity
File: contracts/core/PosManager.sol

291:         uint nonce = nextNonces[_owner]++;

```

### <a name="GAS-6"></a>[GAS-6] Splitting require() statements that use && saves gas

*Instances (4)*:
```solidity
File: contracts/core/InitCore.sol

132:         _require(poolConfig.canBorrow && _config.getModeStatus(mode).canBorrow, Errors.BORROW_PAUSED);

206:         _require(currentModeStatus.canRepay && newModeStatus.canRepay, Errors.REPAY_PAUSED);

543:         _require(_config.getPoolConfig(_pool).canRepay && _config.getModeStatus(_mode).canRepay, Errors.REPAY_PAUSED);

```

```solidity
File: contracts/hook/MarginTradingHook.sol

432:         _require(_tokenA != address(0) && _tokenB != address(0), Errors.ZERO_VALUE);

```

### <a name="GAS-7"></a>[GAS-7] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (14)*:
```solidity
File: contracts/core/InitCore.sol

316:         if (shares > 0) IPosManager(POS_MANAGER).removeCollateralTo(_posId, _poolOut, shares, msg.sender);

354:         if (wLpAmtToBurn > 0) {

507:         health_e18 = borrowCredit_e36 > 0

```

```solidity
File: contracts/core/PosManager.sol

195:         uint newDebtAmt = ILendingPool(_pool).totalDebtShares() > 0

201:         if (newDebtShares > 0) __posBorrInfos[_posId].pools.add(_pool);

252:         _require(_shares > 0, Errors.ZERO_VALUE);

```

```solidity
File: contracts/helper/swap_helper/MoeSwapHelper.sol

36:         if (balance > 0) IERC20(_token).safeTransfer(msg.sender, balance);

```

```solidity
File: contracts/lending_pool/LendingPool.sol

129:         shares = _totalDebt > 0 ? _amt.mulDiv(totalDebtShares, _totalDebt, MathUpgradeable.Rounding.Up) : _amt;

159:             if (reserve > 0) {

169:         shares = totalDebt > 0 ? _amt.mulDiv(totalDebtShares, totalDebt, MathUpgradeable.Rounding.Up) : _amt;

179:         amt = totalDebtShares > 0 ? _shares.mulDiv(totalDebt, totalDebtShares, MathUpgradeable.Rounding.Up) : 0;

213:         supplyRate_e18 = _cash + _totalDebt > 0

```

```solidity
File: contracts/risk_manager/RiskManager.sol

73:         if (_deltaShares > 0) {

```

```solidity
File: contracts/wrapper/WLpMoeMasterChef.sol

325:             if (amt > 0) IERC20(rewardToken).safeTransfer(_to, amt);

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) |  `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()` | 1 |
| [L-2](#L-2) | Do not use deprecated library functions | 6 |
| [L-3](#L-3) | Empty Function Body - Consider commenting why | 8 |
| [L-4](#L-4) | Initializers could be front-run | 27 |
### <a name="L-1"></a>[L-1]  `abi.encodePacked()` should not be used with dynamic types when passing the result to a hash function such as `keccak256()`
Use `abi.encode()` instead which will pad items to 32 bytes, which will [prevent hash collisions](https://docs.soliditylang.org/en/v0.8.13/abi-spec.html#non-standard-packed-mode) (e.g. `abi.encodePacked(0x123,0x456)` => `0x123456` => `abi.encodePacked(0x1,0x23456)`, but `abi.encode(0x123,0x456)` => `0x0...1230...456`). "Unless there is a compelling reason, `abi.encode` should be preferred". If there is only one argument to `abi.encodePacked()` it can often be cast to `bytes()` or `bytes32()` [instead](https://ethereum.stackexchange.com/questions/30912/how-to-compare-strings-in-solidity#answer-82739).
If all arguments are strings and or bytes, `bytes.concat()` should be used instead

*Instances (1)*:
```solidity
File: contracts/core/PosManager.sol

292:         posId = uint(keccak256(abi.encodePacked(_owner, nonce)));

```

### <a name="L-2"></a>[L-2] Do not use deprecated library functions

*Instances (6)*:
```solidity
File: contracts/helper/rebase_helper/mUSDUSDYHelper.sol

14:         IERC20(_yieldBearingToken).safeApprove(_rebaseToken, type(uint).max);

```

```solidity
File: contracts/helper/swap_helper/MoeSwapHelper.sol

41:             IERC20(_token).safeApprove(ROUTER, type(uint).max);

```

```solidity
File: contracts/hook/BaseMappingIdHook.sol

30:             IERC20(_token).safeApprove(CORE, type(uint).max);

```

```solidity
File: contracts/hook/MoneyMarketHook.sol

126:             IERC20(_token).safeApprove(CORE, type(uint).max);

```

```solidity
File: contracts/lending_pool/LendingPool.sol

91:         IERC20(_underlyingToken).safeApprove(core, type(uint).max);

```

```solidity
File: contracts/wrapper/WLpMoeMasterChef.sol

127:         IERC20(_lp).safeApprove(MASTER_CHEF, _amt);

```

### <a name="L-3"></a>[L-3] Empty Function Body - Consider commenting why

*Instances (8)*:
```solidity
File: contracts/common/AccessControlManager.sol

9:     constructor() AccessControlDefaultAdminRules(0, msg.sender) {}

```

```solidity
File: contracts/common/TransparentUpgradeableProxyReceiveETH.sol

10:     {}

12:     receive() external payable override {}

```

```solidity
File: contracts/core/Config.sol

46:     function initialize() external initializer {}

```

```solidity
File: contracts/oracle/InitOracle.sol

37:     function initialize() external initializer {}

53:         } catch {}

61:             } catch {}

```

```solidity
File: contracts/risk_manager/RiskManager.sol

46:     function initialize() external initializer {}

```

### <a name="L-4"></a>[L-4] Initializers could be front-run
Initializers could be front-run, allowing an attacker to either set their own values, take ownership of the contract, and in the best case forcing a re-deployment

*Instances (27)*:
```solidity
File: contracts/core/Config.sol

46:     function initialize() external initializer {}

46:     function initialize() external initializer {}

```

```solidity
File: contracts/core/InitCore.sol

86:     function initialize(address _config, address _oracle, address _liqIncentiveCalculator, address _riskManager)

88:         initializer

90:         __ReentrancyGuard_init();

```

```solidity
File: contracts/core/LiqIncentiveCalculator.sol

40:     function initialize(uint _maxLiqIncentiveMultiplier_e18) external initializer {

40:     function initialize(uint _maxLiqIncentiveMultiplier_e18) external initializer {

```

```solidity
File: contracts/core/PosManager.sol

69:     function initialize(string calldata _name, string calldata _symbol, address _core, uint8 _maxCollCount)

71:         initializer

73:         __ERC721_init(_name, _symbol);

```

```solidity
File: contracts/hook/MarginTradingHook.sol

63:     function initialize(address _swapHelper) external initializer {

63:     function initialize(address _swapHelper) external initializer {

```

```solidity
File: contracts/hook/MoneyMarketHook.sol

63:     function initialize() external initializer {

63:     function initialize() external initializer {

64:         __ReentrancyGuard_init();

```

```solidity
File: contracts/lending_pool/LendingPool.sol

76:     function initialize(

83:     ) external initializer {

85:         __ERC20_init(_name, _symbol);

```

```solidity
File: contracts/oracle/Api3OracleReader.sol

41:     function initialize(address _api3ServerV1) external initializer {

41:     function initialize(address _api3ServerV1) external initializer {

```

```solidity
File: contracts/oracle/InitOracle.sol

37:     function initialize() external initializer {}

37:     function initialize() external initializer {}

```

```solidity
File: contracts/risk_manager/RiskManager.sol

46:     function initialize() external initializer {}

46:     function initialize() external initializer {}

```

```solidity
File: contracts/wrapper/WLpMoeMasterChef.sol

103:     function initialize(string calldata _name, string calldata _symbol) external initializer {

103:     function initialize(string calldata _name, string calldata _symbol) external initializer {

104:         __ERC721_init(_name, _symbol);

```

