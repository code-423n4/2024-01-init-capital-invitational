# INIT Capital Invitational audit details
- Total Prize Pool: $25,000 in USDC 
  - HM awards: 18,612 in USDC 
  - Analysis awards: $1,034 in USDC 
  - QA awards: $517 in USDC 
  - Gas & Bytecode Size* awards: $517 in USDC
  - Judge awards: $3,820 in USDC 
  - Scout awards: $500 USDC 
- Join [C4 Discord](https://discord.gg/code4rena) to register
- Submit findings [using the C4 form](https://code4rena.com/contests/2024-01-init-capital-invitational/submit)
- [Read our guidelines for more details](https://docs.code4rena.com/roles/wardens)
- Starts January 26, 2024 20:00 UTC 
- Ends February 02, 2024 20:00 UTC 

*For this contest, we will be adding Bytecode Size award for Bytecode Size optimizations for reduction of `InitCore.sol` and `MarginTradingHook.sol` contracts, since they are close to reaching the bytecode size limit.

## Automated Findings / Publicly Known Issues

The 4naly3er report can be found [here](https://github.com/code-423n4/2024-01-init-capital-invitational/blob/main/4naly3er-report.md).

Automated findings output for the audit can be found [here](https://github.com/code-423n4/2024-01-init-capital-invitational/blob/main/bot-report.md) within 24 hours of audit opening.

_Note for C4 wardens: Anything included in this `Automated Findings / Publicly Known Issues` section is considered a publicly known issue and is ineligible for awards._

Known issues:
- For Margin Trading Hook, it is possible that `burnTo` may block users from closing the position, so we plan to create a new collateral pool that will only allow only lending and no borrowing.
- Wrapped LPs and new changes to PosManager no longer uses ERC721 `safeMint`, so it is possible for contracts to receive ERC721 even if it does not implement ERC721Holder.
- Users can avoid paying flashloan fee (if set to non-zero) by atomically borrowing and then repaying in the same transaction.
- `totalInterest` may slightly overestimate the actual interest accrual due to rounding up (in the order of wei).
- In Margin Trading Hook, the difference between trigger price and limit price is capturable by MEV if the diff is large enough.
- Stop loss and take profit orders in margin trading hook may not guarantee it gets executed if the premium is not enough.
- Merchant Moe LP price is inflatable (increase).


# Overview

INIT Capital is a composable liquidity hook money market that allows any DeFi protocols to permissionlessly build liquidity hook plugins and borrow liquidity to execute various DeFi strategies from simple to complex strategies. Additionally, end users on INIT Capital have access to all hooks, which are yield generating strategies, in a few clicks without having to use and manage many accounts and positions on multiple DeFi applications. 

More overview is provided in [the following document](https://docsend.com/view/mwwb5ptmyjkk86ih) (password: Audit)

### Technical Overview

INIT Key features include:
- Multi-Silo Position: Each wallet address can manage multiple isolated positions, having a separate position id.
- Flashloan 
- Multicall: A batched sequence of actions executed through multicall. Users have the option to borrow first and collateralize later.
- LP tokens as collateral by utilizing wrapped LPs.
- Interest rate model.

**InitCore** - The primary entrypoint for most interactions. Users can perform actions directly to each function or utilize multicall to batch several actions together. Key actions include:
- mintTo: Depositing tokens and receiving shares in return.
- burnTo: Burning tokens to redeem the underlying assets.
- collateralize: Transferring the deposited tokens to collateralize a position.
- decollateralize: Reversing the collateralization process.
- borrow: Borrowing tokens out of the system
- repay: Repaying borrowed tokens

**LendingPool** - Manages the supply and the total debt share.

**PosManager** - Manages each position, including the debt shares of each borrowed token, and also the collaterals

**LiqIncentiveCalculator** - Handles liquidation incentive calculation. It is currently based on how unhealthy the position is.

**MoneyMarketHook** - Hook implementation for regular money market actions: deposit, withdraw, borrow, repay.

**WLp** - Wrapped LP contract (currently not in scope, since this is pending integration with certain DEXs). This should also handle reward calculations.

**InitOracle** - Aggregate underlying oracle prices by using primary & secondary sources.

**RiskManager** - Handles potential risk that may arise in the money market, for example, large price impact from having too much concentration of collateralization (currently handled by the introduction of debt ceiling per mode).

NEW:
**MarginTradingHook** - Hook implementation for margin trading actions. Some features include margin trading, stop loss, and take profit actions.

**WLpMoeMasterChef** - Wrapped LP contract implementation for [Merchant Moe DEX](https://merchantmoe.com/) (with MasterChef staking contract).

**MoeSwapHelper** - Helper contract for swapping tokens on Merchant Moe DEX.




![flow](https://github.com/code-423n4/2023-12-initcapital/blob/main/resources/diagram_flow.png?raw=true)

## Links


- **Previous audits:** See [audits folder](https://github.com/init-capital/init-core-public/tree/master/audits)
- **Documentation:** 
  - Gitbook: https://init-capital.gitbook.io/
  - Overview: https://docsend.com/view/mwwb5ptmyjkk86ih (password: Audit)
- **Website:** https://init.capital/ 
- **DApp**: https://app.init.capital/
- **Twitter:** [https://twitter.com/InitCapital_](https://twitter.com/InitCapital_)
- **Discord:** https://discord.gg/hW3YZSMzvv

# Scope

Part 1 scope: new contracts
| Contract | SLOC | Purpose | 
| ----------- | ----------- |  ----------- |
| [contracts/wrapper/WLpMoeMasterChef.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/wrapper/WLpMoeMasterChef.sol) | 209 | Wrapped LP for Merchant Moe integration |
| [contracts/hook/MarginTradingHook.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/hook/MarginTradingHook.sol) | 468 | Hook implementation for margin trading actions |
| [contracts/common/InitErrors.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/common/Multicall.sol) | 58 (most lines are just trivial constants, which can be ignored) | Error library |
| [contracts/helper/swap_helper/MoeSwapHelper.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/helper/swap_helper/MoeSwapHelper.sol) | 33 | Swap helper for Merchant Moe DEX |
| [contracts/hook/BaseMappingIdHook.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/hook/BaseMappingIdHook.sol) | 21 | Base implementation for hook |


Part 2 scope: mitigation reviews + minor changes to the previous code4rena contest

| Contract | SLOC | Purpose | 
| ----------- | ----------- | ----------- |
| [contracts/common/library/UncheckedIncrement.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/common/library/UncheckedIncrement.sol) | 8 | Unchecked Increment for `uint` iterators | 
| [contracts/common/AccessControlManager.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/common/AccessControlManager.sol) | 9 | Manage access controls | 
| [contracts/common/UnderACM.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/common/UnderACM.sol) | 8 | Extensible contract for access control manager | 
| [contracts/core/Config.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/core/Config.sol) | 106 | Config manager | 
| [contracts/core/InitCore.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/core/InitCore.sol) | 423 | Main contract for most interactions to INIT | 
| [contracts/core/LiqIncentiveCalculator.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/core/LiqIncentiveCalculator.sol) | 80 | Liquidation incentive calculation  | 
| [contracts/core/PosManager.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/core/PosManager.sol) | 263 | Position manager  | 
| [contracts/hook/MoneyMarketHook.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/hook/MoneyMarketHook.sol) | 180 | Hook for regular money market actions, for example, deposit, withdraw, borrow, repay  | 
| [contracts/lending_pool/DoubleSlopeIRM.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/lending_pool/DoubleSlopeIRM.sol) | 29 | Interest rate model utilizing a 2-slope mechanism  | 
| [contracts/lending_pool/LendingPool.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/lending_pool/LendingPool.sol) | 183 | ERC20 lending pool | 
| [contracts/oracle/Api3OracleReader.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/oracle/Api3OracleReader.sol) | 55 | API3 oracle integration | 
| [contracts/oracle/InitOracle.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/oracle/InitOracle.sol) | 77 | Oracle source manager contract | 
| [contracts/risk_manager/RiskManager.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/risk_manager/RiskManager.sol) | 61 | Risk manager contract |
| [contracts/helper/rebase_helper/mUSDUSDYHelper.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/helper/rebase_helper/mUSDUSDYHelper.sol) | 23 | Wrapper contract helper for wrapping/unwrapping mUSD to/from USDY |
| [contracts/helper/rebase_helper/BaseRebaseHelper.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/helper/rebase_helper/BaseRebaseHelper.sol) | 11 | Base wrapper contract helper for wrapping/unwrapping rebase tokens |
| [contracts/common/TransparentUpgradeableProxyReceiveETH.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/common/TransparentUpgradeableProxyReceiveETH.sol) | 9 | Transparent upgradeable proxy that allows receiving ETH at the proxy level to avoid out-of-gas errors |
| [contracts/common/Multicall.sol](https://github.com/code-423n4/2024-01-init-capital-invitational/tree/main/contracts/common/Multicall.sol) | 20 | Extensible multicall base logic |

## Out of scope

- `contracts/interfaces/*`
- `contracts/mock/*`
- `contracts/oracle/PythOracleReader.sol`
- `tests/`
- `contracts/helper/InitLens.sol`
- `contracts/helper/MarginTradingLens.sol`
# Additional Context

- [ ] Describe any novel or unique curve logic or mathematical models implemented in the contracts
- [ ] Please list specific ERC20 that your protocol is anticipated to interact with. Could be "any" (literally anything, fee on transfer tokens, ERC777 tokens and so forth) or a list of tokens you envision using on launch.
  - No fee-on-transfer tokens
- [ ] Please list specific ERC721 that your protocol is anticipated to interact with.
  - In general, we do not support ERC721. However, we may be able to support UniswapV3-like LP tokens, which is a form of ERC721 if minted through the NPM.
- [ ] Which blockchains will this code be deployed to, and are considered in scope for this audit?
  - Mantle blockchain
- [ ] Please list all trusted roles (e.g. operators, slashers, pausers, etc.), the privileges they hold, and any conditions under which privilege escalation is expected/allowable
- [ ] In the event of a DOS, could you outline a minimum duration after which you would consider a finding to be valid? This question is asked in the context of most systems' capacity to handle DoS attacks gracefully for a certain period.
- [ ] Is any part of your implementation intended to conform to any EIP's? If yes, please list the contracts in this format: 
  - Positions should be `ERC721`.

## Attack ideas (Where to look for bugs)

- Infinite collateralization or borrowing.
- Malicious custom callbacks that can steal funds, either directly or indirectly (for example, via token approvals)
- Incorrect interest accrual or debt calculations
- Bypassing position health check, especially when performing `multicall`
- Margin Trading Hook - can some series of actions on the hook lead the position to be in a weird state and lose money ? 
- Wrapped LP Merchant Moe - LP price manipulation.


## Main invariants

- Over-collateralization of the positions


## Scoping Details 

```
- If you have a public code repo, please share it here: -
- How many contracts are in scope?: 5 new + mitigations & minor changes to previous contracts
- Total SLoC for these contracts?: 729 new + <100 line diff from part2
- How many external imports are there?: Many (most are OpenZeppelin's library)
- How many separate interfaces and struct definitions are there for the contracts within scope?: 30 interfaces, 23 structs
- Does most of your code generally use composition or inheritance?: Composition   
- How many external calls?: major one is via InitCore's callback
- What is the overall line coverage percentage provided by your tests?: 90%+
- Is this an upgrade of an existing system?: It is a modification of the previous contracts
- Check all that apply (e.g. timelock, NFT, AMM, ERC20, rollups, etc.): ERC-20 Token, Multi-Chain 
- Is there a need to understand a separate part of the codebase / get context in order to audit this part of the protocol?: True (merchant moe)  
- Please describe required context: see documentation above.  
- Does it use an oracle?: Yes, currently using API3.
- Describe any novel or unique curve logic or mathematical models your code uses: -
- Is this either a fork of or an alternate implementation of another project?: False   
- Does it use a side-chain?: No
- Describe any specific areas you would like addressed: -
```
# Tests

1. Install Foundry's Forge and ApeWorX's ape.
- Forge: https://github.com/foundry-rs/forge-std
- Ape: https://github.com/ApeWorX/ape

2. Installing libraries via Ape and Forge.
    ```shell
    ape plugins install .
    ape compile
    forge install foundry-rs/forge-std --no-commit
    ```

(To compile the code, you can use either `ape compile` or `forge build` after installing the libraries)

3. Spin up an anvil fork node

    ```shell
    anvil -f https://rpc.mantle.xyz --chain-id 5000
    ```

4. Run tests

    ```shell
    forge test
    ```

For coverage testing, run the following intead of step 3, and a new window will pop up on your browser. 
*NOTE: Make sure you have an up-to-date `lcov` installed.*

```shell
sh run_coverage.sh
```
