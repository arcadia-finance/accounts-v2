# Arcadia Accounts

[![Foundry][foundry-badge]][foundry]
[![License: BUSL-1.1][license-badge]](LICENSE.md)
[![Docs][docs-badge]][docs]

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[license-badge]: https://img.shields.io/badge/License-BUSL--1.1-blue.svg
[docs]: https://docs.arcadia.finance
[docs-badge]: https://img.shields.io/badge/Docs-docs.arcadia.finance-0A0A0A.svg

Smart contracts for Arcadia Accounts, the core of the [Arcadia Protocol](https://arcadia.finance). Arcadia is a non-custodial, composable margin protocol for leveraged yield strategies on AMM liquidity positions, live on Base, Optimism, Unichain and Robinhood.

This repository contains the Account logic, the Factory that deploys Accounts, and the Registry with its Asset and Oracle Modules that price everything an Account holds. Related repositories:

- [lending-v2](https://github.com/arcadia-finance/lending-v2): Lending Pools (the main Creditor for Margin Accounts) and the Liquidator.
- [asset-managers](https://github.com/arcadia-finance/asset-managers): automation for Accounts (compounders, rebalancers, yield claimers, Merkl operators, CoW swapper).
- [arcadia-finance-audits](https://github.com/arcadia-finance/arcadia-finance-audits): all audit reports.

## Overview

### Accounts

An Arcadia Account is a smart contract wallet with a single owner. It holds the owner's assets and is the interface to manage them, either directly or through Asset Managers the owner approves. The [Factory](src/Factory.sol) deploys every Account as an [ERC-1967](https://eips.ethereum.org/EIPS/eip-1967) [proxy](src/Proxy.sol) and is itself an ERC-721 contract: each Account is an NFT, so ownership can be transferred with standard tooling.

There are two types of Accounts:

- **Spot Accounts** can hold any asset but cannot carry debt. They are fully permissionless.
- **Margin Accounts** open a position with a Creditor (for example a Lending Pool) and can carry liabilities against the assets they hold. They only accept assets the Creditor allows, and must stay over-collateralised.

### Account versions

Account logic is versioned in the Factory. Owners can upgrade an existing Account to another version without moving assets or closing debt. Upgrades are always opt-in, and for Margin Accounts the Creditor must accept the new version as well.

| Version | Source                                       | Type   | Implementation                               |
| ------- | -------------------------------------------- | ------ | -------------------------------------------- |
| 1       | [`AccountV1.sol`](src/accounts/AccountV1.sol) | Margin | `0xbea2B6d45ACaF62385877D835970a0788719cAe1` |
| 2       | [`AccountV2.sol`](src/accounts/AccountV2.sol) | Spot   | `0xd8AF1F1dEe6EA38f9c08b5cfa31e01ad2Bfbef28` |
| 3       | [`AccountV3.sol`](src/accounts/AccountV3.sol) | Margin | `0x78Db6a136EdD0F70bEd7a6eb5ca2fDF6eE16E8D6` |
| 4       | [`AccountV4.sol`](src/accounts/AccountV4.sol) | Spot   | `0xe976BFb44f9322164ca6fdA6C5B84fBb6163D442` |

Versions 3 and 4 are available on every supported chain. All versions share the storage layout in [`AccountStorageV1`](src/accounts/AccountStorageV1.sol).

### Flash Actions

A Flash Action executes arbitrary multi-step logic with an Account's assets in a single transaction: optimistically withdraw assets, borrow from the Creditor, swap, stake, rebalance or refinance, and deposit the result back. The Account may be under-collateralised in between. The only requirement is that it is healthy at the end, otherwise the whole transaction reverts.

### Asset Managers

Owners can approve one or more Asset Managers per Account. An Asset Manager can deposit, withdraw and execute Flash Actions on the owner's behalf, which enables automation such as compounding fees, rebalancing liquidity positions and claiming rewards without giving up self-custody.

### Creditors and margin

A Creditor is any contract that holds liabilities against Margin Accounts and implements [`ICreditor`](src/interfaces/ICreditor.sol) (base contract: [`Creditor`](src/abstracts/Creditor.sol)). Lending Pools are one example; perpetuals, options or other debt-based products can integrate the same way. Each Creditor appoints a Risk Manager who sets, per asset, a collateral factor, a liquidation factor and exposure caps.

The health of a Margin Account is derived from:

- **Collateral value**: the sum of each asset's value multiplied by its collateral factor.
- **Liquidation value**: the sum of each asset's value multiplied by its liquidation factor.
- **Used margin**: the open position with the Creditor plus the Creditor's minimum margin.

An Account can withdraw or take on more debt as long as its used margin stays below its collateral value. Once the used margin exceeds the liquidation value, anyone can trigger a liquidation, which is run as a Dutch auction by the Liquidator in [lending-v2](https://github.com/arcadia-finance/lending-v2).

### Pricing

All assets are priced on-chain by the [Registry](src/registries), in the numeraire of the Account's Creditor. The Registry delegates to modules that can only be appended, never removed or replaced:

- **Oracle Modules** normalise price feeds from different oracle providers (Chainlink, RedStone).
- **Primary Asset Modules** price assets that are not composed of other assets, such as ERC20 tokens, using one or more oracles.
- **Derived Asset Modules** price composed assets, such as LP positions or staked positions, by decomposing them into their underlying assets and asking the Registry, recursively, for the value of each of those.

Asset Modules also store the risk parameters and track the exposure per Creditor for their assets. [`RegistryL2`](src/registries/RegistryL2.sol) additionally checks a sequencer uptime feed and halts pricing while the sequencer is down, or within a grace period after it comes back up.

### Supported assets

| Assets | Asset Modules |
| --- | --- |
| ERC20 tokens with an on-chain price feed | [`ERC20PrimaryAM`](src/asset-modules/ERC20-Primaries/ERC20PrimaryAM.sol) |
| The chain's native token | [`NativeTokenAM`](src/asset-modules/native-token/NativeTokenAM.sol) |
| Uniswap V3 liquidity positions | [`UniswapV3AM`](src/asset-modules/UniswapV3/UniswapV3AM.sol) |
| Uniswap V4 liquidity positions, routed to an Asset Module per hook | [`DefaultUniswapV4AM`](src/asset-modules/UniswapV4/DefaultUniswapV4AM.sol), [`UniswapV4HooksRegistry`](src/asset-modules/UniswapV4/UniswapV4HooksRegistry.sol) |
| Aerodrome and Velodrome Slipstream positions, unstaked or staked | [`SlipstreamAM`](src/asset-modules/Slipstream/SlipstreamAM.sol), [`StakedSlipstreamAM`](src/asset-modules/Slipstream/StakedSlipstreamAM.sol) |
| Aerodrome and Velodrome pool LP tokens: held directly, wrapped, or staked | [`AerodromePoolAM`](src/asset-modules/Aerodrome-Finance/AerodromePoolAM.sol), [`WrappedAerodromeAM`](src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol), [`StakedAerodromeAM`](src/asset-modules/Aerodrome-Finance/StakedAerodromeAM.sol) |
| Metadex03 pool LP tokens and concentrated liquidity positions | [`Metadex03PoolAM`](src/asset-modules/Metadex03/Metadex03PoolAM.sol), [`WrappedMetadex03AM`](src/asset-modules/Metadex03/WrappedMetadex03AM.sol), [`StakedMetadex03AM`](src/asset-modules/Metadex03/StakedMetadex03AM.sol), [`Metadex03CLAM`](src/asset-modules/Metadex03/Metadex03CLAM.sol), [`StakedMetadex03CLAM`](src/asset-modules/Metadex03/StakedMetadex03CLAM.sol) |
| Stargate Finance LP tokens, unstaked or staked | [`StargateAM`](src/asset-modules/Stargate-Finance/StargateAM.sol), [`StakedStargateAM`](src/asset-modules/Stargate-Finance/StakedStargateAM.sol) |

Oracle Modules: [`ChainlinkOM`](src/oracle-modules/ChainlinkOM.sol) and [`RedStonePushOM`](src/oracle-modules/RedStonePushOM.sol).

## Repository structure

```
src
├── Factory.sol         Deploys Accounts, tracks ownership (ERC-721), manages versions and upgrades
├── Proxy.sol           ERC-1967 proxy that every Account is deployed as
├── abstracts/          Creditor base contract
├── accounts/           Account implementations (V1 to V4), shared storage layout, AccountsGuard
├── asset-modules/      Primary and Derived Asset Modules, one folder per protocol
├── guardians/          Emergency pause logic for the Factory and the Registry
├── oracle-modules/     Chainlink and RedStone Oracle Modules
├── registries/         Registry for L1s and for L2s
├── interfaces/
└── libraries/
test
├── fuzz/               Fuzz tests, one folder per contract
├── invariant/          Invariant tests
└── utils/              Fixtures, mocks and test extensions
```

## Deployments

The core contracts have the same address on every supported chain: Base (8453), Optimism (10), Unichain (130) and Robinhood (4663).

| Contract | Address                                      |
| -------- | -------------------------------------------- |
| Factory  | `0xDa14Fdd72345c4d2511357214c5B89A919768e59` |
| Registry | `0xd0690557600eb8Be8391D1d97346e2aab5300d5f` |

Asset Modules, Oracle Modules and all other contracts are listed per chain in the [contract addresses](https://docs.arcadia.finance/developers/contract-addresses/smart-contracts) docs.

## Development

Requires [Foundry](https://getfoundry.sh/).

```shell
git clone https://github.com/arcadia-finance/accounts-v2.git
cd accounts-v2
git submodule update --init
git submodule update --init --recursive lib/slipstream lib/v4-periphery
forge build
```

Run the tests:

```shell
forge test
```

Fuzz runs are set per Foundry profile: `default` (50 runs), `gh` (200 runs, used in CI) and `hf` (2,000 runs):

```shell
FOUNDRY_PROFILE=hf forge test
```

CI also checks formatting with `forge fmt --check`.

## Integrating

- [Building a Creditor](https://docs.arcadia.finance/developers/integrations/creditors)
- [Building an Asset Manager](https://docs.arcadia.finance/developers/integrations/asset-managers)
- [Running a liquidation bot](https://docs.arcadia.finance/developers/integrations/liquidators)
- [Wallets and indexers](https://docs.arcadia.finance/developers/integrations/wallets)

## Security

The contracts in this repository have been reviewed in the following audits:

| Date | Auditor | Scope | Report |
| --- | --- | --- | --- |
| 2023-12 | Trust Security | Full Arcadia V2 codebase | [PDF](https://github.com/arcadia-finance/arcadia-finance-audits/blob/main/audits-v2/2023-12%20Trust%20Security.pdf) |
| 2024-01 | Pashov Audit Group | Full Arcadia V2 codebase | [PDF](https://github.com/arcadia-finance/arcadia-finance-audits/blob/main/audits-v2/2024-01%20Pashov%20Group.pdf) |
| 2024-01 | Renascence | Full Arcadia V2 codebase | [PDF](https://github.com/arcadia-finance/arcadia-finance-audits/blob/main/audits-v2/2024-01%20Renascense.pdf) |
| 2024-02 | Sherlock (contest) | Full Arcadia V2 codebase | [PDF](https://github.com/arcadia-finance/arcadia-finance-audits/blob/main/audits-v2/2024-02%20Sherlock.pdf) |
| 2024-04 | Sherlock (contest) | Aerodrome Asset Modules | [PDF](https://github.com/arcadia-finance/arcadia-finance-audits/blob/main/audits-v2/2024-04%20Sherlock.pdf) |
| 2024-06 | Renascence | Staked Slipstream Asset Module | [PDF](https://github.com/arcadia-finance/arcadia-finance-audits/blob/main/audits-v2/2024-06%20Renascense.pdf) |
| 2024-10 | Pashov Audit Group | Spot Accounts, Uniswap V4 Asset Module | [PDF](https://github.com/arcadia-finance/arcadia-finance-audits/blob/main/audits-v2/2024-10%20Pashov%20Group.pdf) |
| 2025-09 | Sherlock | Accounts V3 and V4, AccountsGuard, Factory, RegistryL1, staked Asset Modules | [PDF](https://github.com/arcadia-finance/arcadia-finance-audits/blob/main/audits-v2/2025-09%20Sherlock.pdf) |
| 2026-01 | Sherlock | Primary Asset Modules, native token Asset Module, Oracle Modules | [PDF](https://github.com/arcadia-finance/arcadia-finance-audits/blob/main/audits-v2/2026-01%20Sherlock.pdf) |

All reports, including those for other Arcadia repositories, are in [arcadia-finance-audits](https://github.com/arcadia-finance/arcadia-finance-audits). See the docs for the protocol's [roles](https://docs.arcadia.finance/security-and-risk/roles), [risk management](https://docs.arcadia.finance/security-and-risk/risk) and [circuit breakers](https://docs.arcadia.finance/security-and-risk/circuit-breakers).

Please report vulnerabilities privately to [security@arcadia.finance](mailto:security@arcadia.finance) instead of opening a public issue. Rewards for eligible findings are paid through the [bug bounty program on HackenProof](https://hackenproof.com/programs/arcadia-finance-company-smart-contracts).

## Contributing

Contributions are welcome. For larger changes, get in touch first on [Discord](https://discord.gg/PXcr8SEeTH) or via dev `[at]` arcadia.finance.

## License

The core contracts are licensed under the Business Source License 1.1, see [LICENSE.md](LICENSE.md) for the Additional Use Grant and Change Date. Interfaces and some libraries carry their own SPDX license identifier.

## Links

[Website](https://arcadia.finance) · [Docs](https://docs.arcadia.finance) · [Discord](https://discord.gg/PXcr8SEeTH) · [X](https://x.com/ArcadiaFi) · [Blog](https://arcadiafinance.medium.com/)
