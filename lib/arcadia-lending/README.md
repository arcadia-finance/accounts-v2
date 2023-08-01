[![Foundry][foundry-badge]][foundry]

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg


# Arcadia Finance - Arcadia Lending

## Name
Arcadia Lending

## Docs
[Arcadia Finance Docs](https://arcadiafinance.notion.site)

## Description
Arcadia Finance is an Open Source protocol building solutions for digital assets, within collateral markets and the broader DeFi ecosystem. Arcadia Vaults are the core of the product suite and are responsible for locking, pricing and managing collateral.

[Arcadia Vaults](https://github.com/arcadia-finance/arcadia-vaults) are user-controlled vaults enabling the on-chain pricing of any combination of different types of assets in one single base currency. Arcadia Vaults are non-custodial and allow its owner to actively manage the collateral contained within the Vault.

Arcadia Lending is the first financial product being built on top of the Arcadia Vaults.

This repo holds the Arcadia Lending smart contracts.

# Arcadia Lending

*Arcadia Lending* is the first application leveraging Arcadia Vaults. It is a non-custodial peer-to-contract lending protocol where users can borrow against a combination of assets.

![Arcadia Lending overview](https://i.ibb.co/G250RR2/Untitledjhghj.png)

## Risk-modelling

The overall goal of risk assessment is to ensure that the probability of a position going under-collateralized (= default event) is below a certain threshold, while maximizing borrower capacity and avoiding premature liquidations. 

There are 2 main parameters in lending applications that need to be optimized to create a system that fulfils the needs of both borrowers and lenders:  the collateral threshold and the liquidation threshold. These parameters create a cushion to mitigate the risk for both parties:

- Collateralization threshold (also known as LTV, loan-to-value or [haircut](https://www.investopedia.com/terms/h/haircut.asp) in TradFi) is the percentage difference between an asset's market value and the amount that can be used as collateral for a loan. It is the initial safety margin and mainly a factor of volatility of underlying assets and price-correlation between different assets.
- Liquidation threshold is the percentage difference between collateral current market value and the loan amount, mainly a function of the available liquidity on-chain and a parameter to optimize LGD ([loss given default](https://www.investopedia.com/terms/l/lossgivendefault.asp)).

These values are not arbitrary values. Determining these values depends on the asset risks, market condition and user preferences. We are working on dynamic models that are based on on-chain data to estimate optimal parameters. Until our research reaches maturity we are following traditional methods to determine these parameters.

We foresee our risk models to be mainly off-chain at the beginning. We nonetheless have the vision to bring our risk models on-chain. Arcadia values open-source and we are planning to make our risk models and research public.

## Collateral

Before borrowers can take out a loan, they need to deposit assets as collateral in their Arcadia Vault. When the borrowers take out their loan, the vault gets locked for withdrawals up until the collateralization threshold. Important to note here is that a certain VALUE gets locked, not the individual assets themselves. The owner can still actively manage the assets within the vault or withdraw assets, as long as the total value of all assets stays above the collateralization threshold.

This is one of the main differentiators between Arcadia Lending and other lending protocols. It allows borrowers to:

- Lend against a portfolio/treasury.
- Actively manage assets under collateral.
- Use new upcoming assets as collateral in existing vaults (new DeFi primitives or even new token standards).
- Reduce the volatility of their collateral value by using diversified collateral assets, or through the creation of hedged positions by using long & short assets in the same vault. This reduces the probability of liquidations and users can achieve a higher LTV.

In theory, Arcadia Vaults can price any asset in a given base currency, but this does not mean that our lending protocol will allow any asset to be used as collateral. Only assets that fulfil certain liquidity, volatility and decentralization criteria (see Risk-Modelling) will be added on the allowlist and can be used as collateral.

Collateral in an Arcadia Vault is fully isolated from the lending pools and Arcadia Vaults of other users. **Borrowers have no risk to lose collateral in case of defaults of other borrowers.**

## Liquidity Pools

The liquidity pools are the hearth of Arcadia Lending. We will initially bootstrap 2 liquidity pools, one for a token pegged to USD (USDC, Dai or other) and a second one for Ethereum.
Liquidity pools for additional tokens can follow later, or even be deployed permissionless as long as there is a reliable and decentralized price oracle.

The two main stakeholders who interact with the Liquidity pools are the borrowers and the liquidity providers:

- The borrowers take out their loans from the liquidity pool and have to pay back their loans with additional interests. There is no fixed loan repayment period, but interests are continuously compounding.
- The liquidity providers deposit the initial liquidity and accrue interest payments as long as they have capital deployed in the pool. There is no fixed lockup period, liquidity providers are free to withdraw their stake from the pool.

The utilization rate is a measure for the balance between the total amount borrowed and the total amount supplied and is defined as the share of the total liquidity that is borrowed out. If the utilization rate is too high, there is not enough liquidity in the pool for lenders to take out additional credit, or for liquidity providers to exit their positions. If the utilization is too low, capital allocated by liquidity providers is not earning sufficient yield. 

Hence for each liquidity pool there exists an optimal utilization rate, typically around 80%. Arcadia Lending will use a reactive interest rate to ensure that the utilization rate remains around the optimum (see next paragraph). 

## Interests

### Interest rates

Arcadia Lending will use a variable interest rate, depending on the utilization rate of the underlying lending pool. The interest rate is a function of supply and demand and not a fixed parameter set by the protocol (or depending on a static predefined linear curve).

Before an LP is willing to allocate any capital, the interest rate should at least cover the risk-free interest rate and a minimal risk premium:

- The risk-free interest rate is a theoretical concept but can be seen as the return on the safest investment possible. For USD (or other fiat currencies) it is defined as the return on [short-term government bonds](https://www.investopedia.com/terms/r/risk-freerate.asp). For PoS blockchains it can be defined as the [staking rewards](https://www.theblock.co/post/158418/ethereum-will-define-web3s-benchmark-interest-rate-post-merge-according-to-raoul-pal) of the underlying chain (if consensus fails, all protocols built on top are impacted as well).
- The minimal risk premium depends on the probability of a default (loss of capital) which in turn depends on the quality of the smart contracts, the protocol design, governance structure and the quantity/quality of the collateralized assets.

Since both the risk-free interest rate and the minimal risk premium are dynamic and depending on factors exogenous to the lending protocol itself, statically defined interest rates will over-or under estimate the optimal interest rate, leading to [capital inefficiencies](https://members.delphidigital.io/reports/dynamic-interest-rate-model-based-on-control-theory/).

Fixed rates for lenders or borrowers might be offered via partnership with DeFi protocols building infrastructure for [interest rate swaps](https://www.voltz.xyz/).

### Interest payments

Every-time a user interacts with the Liquidity pool (depositing/withdrawing liquidity, taking/repaying loans), the accounting logic for interest payments is triggered and the new interest rate is calculated, depending on the utilization of the lending pool (see above). Interests are continuously compounding.

The ERC-4626 standard is used to represent both the open debt of borrowers, as the interest bearing positions of liquidity providers (see next paragraph). Using the ERC-4626 standard makes the accounting logic gas efficient and ensures composability with existing protocols and infrastructure.

A fixed percentage of the interest payments will go to Arcadia Finance’s treasury.

### Risk Tranches

Different LPs have different risk appetite, therefore we will create per lending pool two (or more) risk tranches. By differentiating LPs according to their risk profile, we can attract more liquidity for a given average interest rate.

Junior risk tranches will earn higher yields, but in case of defaults (=under-collateralized positions) the junior tranches will lose part of their underlying tokens (more on that in Liquidation paragraph).

As mentioned in the previous paragraph, each risk tranche is according to the new ERC-4626 standard.

## Liquidations

For liquidating unhealthy vaults we rely on MEV bots and keeper networks as much as possible. We avoid having a single point of failure, and we let MEV searchers compete in the free market to optimize routing of the assets to be liquidated.

Liquidation is a two-step process, for which both cases we rely on MEV searchers:

- Anyone can start the liquidation process of a vault of which the health factor drops below the liquidation threshold. In return, the liquidator who starts the process immediately receives a percentage of the Vaults position.
- The liquidation process itself will be a [Gradual Dutch Auction](https://www.paradigm.xyz/2022/04/gda): the selling price of the vault will constantly decrease until a buyer steps in. The buyer who can liquidate the vault with the least slippage will be the first one to be profitable. This ensures optimal liquidation of unhealthy vaults.

Since one vault can consist of multiple assets, we will allow partial liquidations. Partial liquidations will help decreasing selling pressure after liquidations for assets with limited on-chain liquidity.

After the vault is sold there are three scenario’s:

1. In case the final selling price is lower than the open debt, a default event occurs. The bad debt is recovered from the underlying tokens of the most junior risk tranche.
![Untitled](https://i.ibb.co/3FWyrYK/Untitled-A.png)

2. In case the final selling price is higher than the open debt, but below the open debt + liquidation penalty cap, there is a surplus that will be distributed according to a fixed ratio to:
    - Arcadia Finance’s treasury
    - The most junior tranche
![Untitled](https://i.ibb.co/9gR3zsk/Untitled-B.png)

3. In case the final selling price is higher than the open debt + liquidation penalty cap, the liquidation penalty will again be distributed to both the protocol and the most junior tranche. The leftover surplus will go back to the original owner of the liquidated vault.
![Untitled](https://i.ibb.co/Fbmc4Hy/Untitled-C.png)

## Dual Governance

Within Arcadia Lending, the following decisions could present themselves: which assets to allow as collateral, parametrization of the protocol (risk parameters, optimal utilizations), deployment of liquidity pools, fee-structure,...

A [dual governance model](https://research.lido.fi/t/ldo-steth-dual-governance/2382) will be established between:
- Arcadia Finance governance
- Liquidity providers

since the incentives of the protocol (earning a lot of fees) might not always align with LP providers who put their capital at risk. The first must propose and work out proposals, but the latter can veto decisions.

## Support
Support questions can be directed to our [Discord](https://discord.gg/PXcr8SEeTH). 

## Contributing
We are open to people looking to make contributions, both on the core contracts and on the front-end/dashboards.
If you'd like to get in touch with us before, please join [our Discord](https://discord.gg/PXcr8SEeTH) or send a mail to dev `[at]` arcadia.finance.

## License
The license can be found [here](LICENSE.md).