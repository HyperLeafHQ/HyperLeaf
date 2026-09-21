# HyperLeaf Comment Index

Canonical asset-evaluation discussion: [issue #7](https://github.com/HyperLeafHQ/HyperLeaf/issues/7). Do not use closed PR #4 as the live index.

## Canonical evaluation series

Only formal asset evaluations receive a numbered `#NN`. Watchlist / No-Go / Already Exists / batch-screening records do not consume a new number unless explicitly promoted. Existing-number corrections are made in-place.

| # | Asset / evaluation | Preferred representation / direction | Status | Comment |
|---|---|---|---|---|
| #00 | Methodology / canonical index | Gate 0 + productive-position framework | Canonical index | [5609277559](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609277559) |
| #01–#44 | Existing canonical series | See canonical #00 index | Existing records | [Issue #7](https://github.com/HyperLeafHQ/HyperLeaf/issues/7) |
| #45 | FLOKI / Floki | FLOKI staking/lock position; convert external rewards to HYPE; no raw spot wrapper | Selected / P1 Research / Production Gated | [5653288714](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5653288714) |
| #46 | THETA / Theta Network | Native THETA Guardian / Validator staking position; convert TFUEL rewards to HYPE; no raw spot wrapper | Selected / P1 Research / Production Gated | [5653547490](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5653547490) |
| #47 | GRT / The Graph | stGRT / GRT liquid-staked position; preserve accrued staking rewards; canonical HyperEVM route required | Selected / P1 Research / Production Gated | [5653572619](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5653572619) |
| #48 | COMP + UNI | Productive Compound / Uniswap fee-capture positions; no raw spot-token wrapper | Strong Watch / Strategic Candidate | [5653660029](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5653660029) |
| #49 | KAIA / Kaia | Native / public-delegation staking position; productive staking accounting; canonical HyperEVM route required | Selected / P1 Research / Production Gated | [5653691020](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5653691020) |
| #50 | DTF / Down To Finance | Verified DTF staking-position / future rebasing claim representation; no raw DTF wrapper | Selected / P1 Research / Production Gated | [5659805040](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5659805040) |
| #51 | FALCON / Falcon Staking Vaults — XAUt / FF / VELVET / AIO / ESPORTS / SPYx | Verified Falcon vault position; prioritize XAUt and non-KYC onchain vaults; no raw spot wrapper | Selected / P1 Research / Production Gated | [5659805040](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5659805040) |

## Non-series completed / consolidated evaluations

| Asset | Decision | Comment |
|---|---|---|
| **TAO / stTAO / tTAO** | **Skip.** Tensorplex Stake & Bridge sunset. No EVM LST. Do not wrap. Issue #48 closed `not_planned`. | [#48](https://github.com/HyperLeafHQ/HyperLeaf/issues/48) |
| KITE / Kite AI | Strong Watch / Strategic Candidate; agent-payment infrastructure + PoS staking; observation only until canonical KITE → HyperEVM representation, productive accounting, liquidity and exits are verified. | [5639822315](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5639822315) |
| STREAM / Streamflow | Strong Watch / Strategic Candidate; real Solana infrastructure, protocol revenue and staking/governance utility, but no current canonical STREAM → HyperEVM route and no direct claim on protocol revenue. Observation only. | [5653220142](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5653220142) |
| LDO | No-Go / Watchlist as standalone Leaf; prefer stETH/wstETH or productive Lido position | 5637940642 |
| BTT | P1 Research Candidate / native BTTC staking; canonical HyperEVM route required | 5637959434 |
| GNO | P1 Strategic Candidate; do not implement yet | 5638008710 |
| PI | Watchlist / No-Go; no standalone Leaf | 5630140642 |
| FLR | P1 Research Candidate; intentionally non-numbered | Historical standalone evaluation |
| **Wagyu.xyz / PerpetualCow** | Infrastructure / OTC-demand watch. **Not a Leaf.** Do not wrap MAX / XMR1. Optional exit rail only, after solvency. Supplement: business comparison + next OTC holes (C1/Pre are our wedge; XMR taken; watch native TON). | Observation [5743723129](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5743723129) · Supplement [5743846799](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5743846799) |
| **Quantus / QTC** | **Pre OTC.** Native no-contract PoW. Bilateral RFQ + HyperEVM USDM escrow + resolver attest. **Not a Leaf. Not VAR factory n=4. Not hQTC. Not principal.** | Report [5757243169](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5757243169) |

## DTF evaluation

DTF is formally promoted to **#50** as a productive staking-position candidate, not as a raw spot-token wrapper.

The current IndexedEx / Down To Finance product defines a DETF (Decentralized ETF) as one token representing a chosen basket or strategy. The protocol-owned product is DTF-DETF, and the official site identifies DTF as the fee-accruing token; current product pages state that app fees buy back DTF. The current staking interface is explicitly a temporary DTF stake while the protocol DETF is being prepared, with a reward reserve and a planned migration into a rebasing claim token.

HyperLeaf should therefore model the economic object as:

`DTF → verified staking position → funded rewards / fee-capture economics → productive claim → HyperEVM Leaf → realize/swap → HYPE`

Raw DTF must not be treated as rate-bearing backing. Market-price appreciation, speculative future protocol growth and protocol-owned treasury assets are not backing unless there is a direct, contractual and realizable claim.

The preferred implementation is a verified staking-position / rebasing claim representation. Production remains gated on the exact staking contract, reward funding mechanics, migration semantics, admin controls, audit status, Robinhood Chain → HyperEVM canonical route, liquidity and complete exit topology.

**Decision: Selected / P1 Research / Production Gated.**

## Falcon Finance Staking Vaults evaluation

Falcon's current Staking Vault product is materially more interesting than treating Falcon as only a USDf/sUSDf stablecoin protocol. The official vault documentation defines the product as an onchain mechanism where users deposit a supported asset into a dedicated vault, retain exposure to the deposited token, enter a fixed lock period, and receive USDf rewards. Falcon states that the yield is generated by proprietary trading strategies and that the vault does **not** mint USDf merely because users stake. After maturity, users can initiate unstaking, followed by a 3-day cooldown, and redeem the original quantity of the deposited token.

Current Falcon app and official product materials identify the multi-asset vault lineup including **FF, VELVET, AIO, ESPORTS, XAUt and SPYx** across different launch phases. The live vault surface currently shows ESPORTS, VELVET and AIO on BNB Chain, while dedicated app pages also exist for FF, XAUt and SPYx. Falcon's official smart-contract registry currently lists the FF staking vault on Ethereum and the ESPORTS + VELVET staking vaults on BNB Smart Chain. SPYx is a Solana vault and Falcon's launch article states that access requires Falcon KYC.

### Why this is relevant to HyperLeaf

This is not native staking in the PoS sense. The productive object is the **user's contractual claim on a Falcon-managed strategy vault**:

`underlying asset → Falcon staking vault → Falcon proprietary trading / yield generation → USDf reward → vault claim → HYPE liquidation`

The original asset remains the principal/backing leg, while USDf is the reward leg. This fits the same economic pattern already accepted for external-reward staking candidates such as FLOKI: the reward token does not need to equal the backing asset.

However, the productive claim is materially more centralized than native staking because yield generation depends on Falcon's proprietary trading operation. Therefore HyperLeaf must not infer yield from the underlying token or from Falcon's headline APR. Only realized and contractually claimable USDf rewards count as yield.

### Asset-by-asset triage

| Asset / vault | Productive position | Yield | Exit | HyperLeaf view |
|---|---|---|---|---|
| **XAUt** | Falcon XAUt Staking Vault | USDf, published 3–5% APR | 180d + 3d cooldown; original XAUt returned | **Strongest candidate** among current vaults because the principal is a tokenized RWA (Tether Gold) and Falcon adds a defined external yield layer. |
| **FF** | Falcon FF Staking Vault | USDf | Fixed lock / maturity flow | **Candidate**, but FF itself is governance/utility and yield is Falcon-paid, not native FF economics. |
| **VELVET** | Falcon VELVET Staking Vault | USDf, published 20–35% estimate at launch | 180d + 3d cooldown | **Candidate / high counterparty risk**; productive claim is the vault position, not VELVET. |
| **AIO** | Falcon AIO Staking Vault | USDf, published 20–35% estimate at launch | 180d lock; weekly reward claim | **Candidate / high counterparty risk**; underlying token is speculative/utility and the yield is external. |
| **ESPORTS** | Falcon ESPORTS Staking Vault | USDf, published 20–35% estimate at launch | 180d + cooldown | **Candidate / high counterparty risk**; treat underlying token volatility separately from USDf yield. |
| **SPYx** | Falcon SPYx Staking Vault | USDf, ~3% projected | 180d lock | **Research only / blocked for permissionless HyperLeaf** until KYC/eligibility and Solana → HyperEVM custody/exit topology are solved. |

Falcon's own transparency page currently shows approximately **$1.63B total reserves**, **$1.17B USDf supply**, **138.3% protocol backing**, and about **4.74% sUSDf APY** as of the 10 Sep 2026 dashboard update. The reserves are heavily custodial: the dashboard breaks assets across multisig, Fireblocks and Ceffu, and the current reserve mix includes BTC, MBTC, ENZOBTC, stablecoins and other tokens. This strengthens the evidence that Falcon has a substantial operating balance sheet, but it also confirms that HyperLeaf would be taking **Falcon counterparty / strategy / custody risk**, not merely smart-contract risk.

### Solvency model

For a Falcon vault Leaf, the correct invariant is:

`Leaf liability <= verified redeemable principal + verified claimable USDf rewards`

Do **not** count:

- the market appreciation of FF / VELVET / AIO / ESPORTS / XAUt / SPYx;
- Falcon's total reserves as if they belong directly to vault depositors;
- projected APR that has not accrued;
- Falcon protocol treasury or USDf overcollateralization that is not contractually attributable to the user's vault position.

The clean implementation is therefore:

`source asset → Falcon vault position → receipt/accounting layer → HyperLeaf Leaf → realized USDf reward → HYPE`

rather than:

`source token → HyperLeaf spot wrapper`

### Production gates

Before implementation HyperLeaf must verify:

1. Exact vault contracts and whether positions are ERC-20/ERC-4626 receipts or account-based claims.
2. Deposit, reward-accrual, claim, maturity, cooldown and withdrawal semantics.
3. Reward-funding source and whether the USDf reward obligation is actually funded/onchain-verifiable.
4. Admin, pause, upgrade and emergency-withdraw controls.
5. Contract audit/security status.
6. Exact chain and canonical representation into HyperEVM.
7. HyperEVM secondary liquidity and a deterministic exit path.
8. For SPYx, KYC/eligibility restrictions must be resolved before any permissionless wrapper is considered.
9. Hard caps based on executable exit liquidity and economically realizable principal.

### Final Assessment

**Falcon Staking Vaults are supportable as productive positions, but they are not equivalent to native staking.** HyperLeaf should treat the Falcon vault receipt/claim as the asset being wrapped and treat Falcon's USDf payment as external yield.

**#51 Decision: Selected / P1 Research / Production Gated.**

Priority within the family:

**XAUt vault > FF vault > VELVET / AIO / ESPORTS vaults > SPYx vault for permissionless HyperLeaf.**

XAUt is the preferred first research target because the principal is an identifiable RWA representation and Falcon provides a defined stablecoin reward. FF is the cleanest crypto-native integration because Falcon already exposes an official FF staking vault contract on Ethereum, but FF remains a governance/utility token and should not be mistaken for productive backing by itself. VELVET/AIO/ESPORTS are structurally usable but carry more underlying-token and Falcon counterparty risk. SPYx is strategically interesting but currently has an explicit KYC/chain restriction that makes it unsuitable for a permissionless HyperLeaf Leaf without a redesigned compliant access layer.

**Final decision: #51 — Falcon Staking Vaults: Selected / P1 Research / Production Gated. No raw-token wrapper; only verified Falcon productive vault positions.**

## FLOKI evaluation

FLOKI is formally promoted to **#45**. The underlying FLOKI staking/locking position is the productive position. TOKEN or any other reward asset is an external reward flow and does not need to be the same token as the underlying principal.

HyperLeaf should treat the economic flow as:

`FLOKI → staking/locking position → reward asset → sell/swap → HYPE → protocol fee → Leaf yield`

The user-facing yield is therefore realized HYPE, not the identity of the reward token. Backing remains the economically realizable FLOKI principal. FLOKI market-price appreciation is not yield. Fee/burn effects are not directly redeemable backing.

Production remains gated on exact staking contract, lock/withdrawal mechanics, reward accrual and funding, admin controls, reward liquidity, swap and slippage controls, canonical HyperEVM representation, bridge custody/recovery, and solvency caps against economically realizable principal and realized HYPE proceeds.

Decision: **Selected / P1 Research / Production Gated.**

## CRV + CVX observation brief

CRV and CVX should be evaluated together because Convex is a major liquid-locker layer for Curve. Curve currently generates protocol fee flows to veCRV lockers, while Convex aggregates Curve voting power and allows users to stake cvxCRV or CVX to receive platform-related rewards. Convex's current interface states that staked CVX earns a share of platform revenue distributed as cvxCRV, while locked CVX earns a different revenue share and governance/voting weight.

For HyperLeaf, the important distinction is representation rather than token labels:

`CRV → veCRV / Curve productive position → fees/rewards → sell/swap → HYPE`

and

`CVX → Convex stake/lock position → platform revenue / cvxCRV + incentives → sell/swap → HYPE`

Curve's 2026 fee data confirms that veCRV has a real revenue stream.

However, neither raw CRV nor raw CVX should automatically be treated as a productive Leaf. The productive unit should be the verified locked/staked position that has a contractual claim to the resulting reward/revenue stream. For CRV, direct veCRV locking has a long lock horizon; Convex-style liquid-locker representations can improve composability but introduce derivative liquidity/depeg and custody assumptions.

**Decision: Strong Watch / Strategic Candidate — combined CRV + CVX.** No new formal number because the Curve ecosystem / scrvUSD work already exists in the formal series.

## THETA evaluation

THETA is formally promoted to **#46** because it represents a genuine native staking productive position rather than a spot-token value proposition. Theta's current official documentation states that THETA is used to stake as a Validator or Guardian node and that staking earns newly generated TFUEL proportionally over time. The documented Guardian minimum is 1,000 THETA, with rewards distributed probabilistically at checkpoint blocks.

HyperLeaf should model the economic flow as:

`THETA → Guardian / Validator staking position → TFUEL rewards → sell/swap → HYPE → protocol fee → Leaf yield`

Backing remains the economically realizable THETA principal represented by the verified staking position. TFUEL is yield. THETA market-price appreciation is not yield and must not create additional Leaf liabilities.

The main production gate is the complete exit topology and canonical representation on HyperEVM.

**Decision: Selected / P1 Research / Production Gated.**

## GRT evaluation

GRT is formally promoted to **#47** because The Graph now has a live liquid-staking path that turns staked GRT into a liquid `stGRT` position representing the underlying staked position plus accrued rewards. The Graph Foundation announced the Phase 1 soft launch on August 25, 2026, and its current vault surface shows an Arbitrum stGRT vault with a NAV/share-price accounting unit.

The underlying economic position is strong under HyperLeaf's framework:

`GRT → delegate / liquid-staked GRT position → query-fee + indexing-reward accrual → stGRT NAV appreciation → realize / exit → sell or swap → HYPE`

The Graph's core protocol is a real data-services marketplace. Indexers stake GRT and earn query fees and indexing rewards, while Delegators can delegate GRT and receive a share of Indexer rewards and query fees. Current official documentation describes typical Delegator returns around 9–12% annually, but HyperLeaf should use realized on-chain accrual rather than headline APR as its accounting input.

The new `stGRT` route is particularly relevant because it solves part of the traditional GRT problem: native delegation has a roughly 28-day undelegation period, while a liquid representation can preserve productivity and improve composability. However, stGRT is currently an Arbitrum-side position; The Graph's own roadmap separately tracks cross-chain GRT liquid staking, and no verified canonical GRT/stGRT → HyperEVM representation has been established here yet.

Therefore the preferred HyperLeaf design is **stGRT or another verified liquid-staked GRT position**, not a raw GRT spot wrapper. The adapter must value shares from the actual underlying productive position, prevent double-counting accrued versus realized rewards, and cap liabilities against economically realizable underlying GRT NAV.

The main production gates are: exact stGRT/vault contract and withdrawal semantics; whether the position can be exited without importing the full native undelegation delay; reward accrual and fee treatment; admin/upgrade controls; Arbitrum → HyperEVM canonical bridge or native representation; HyperEVM liquidity; and a safe realized-reward → HYPE liquidation path.

**Decision: Selected / P1 Research / Production Gated.** GRT is materially stronger than a normal utility/governance token because its economic role is tied directly to a productive decentralized data-service network and now has a liquid-staking representation. The next step is on-chain verification of stGRT and its complete HyperEVM exit topology.

## COMP + UNI evaluation

COMP and UNI are evaluated together as **DeFi protocol value-capture / governance tokens**. The key HyperLeaf question is not whether Compound or Uniswap generates real economic activity, but whether the token itself represents a sufficiently direct, verifiable and realizable productive economic position that can safely back a Leaf.

### COMP — Compound

Compound is a genuine productive lending protocol: users supply and borrow assets, creating interest and protocol-level revenue/reserve flows. However, raw COMP does **not** represent a direct pro-rata claim on those lending cash flows.

Economic structure:

`Compound lending activity → interest / protocol revenue → protocol reserves / governance`

This is materially different from:

`COMP holder → contractual claim on Compound revenue`

Therefore HyperLeaf should **not** treat spot COMP appreciation, DAO treasury value, or protocol revenue as COMP backing. Any future Compound implementation should instead target an explicitly productive position such as a verified lending/vault receipt whose NAV and accrued interest are contractually attributable to the position holder.

Preferred direction:

`productive Compound position → interest accrual → realize/swap → HYPE`

Not:

`COMP → HYPE`

**COMP decision: Strong Watch / Strategic Watch.**

### UNI — Uniswap

UNI is also a governance token, but its economic position is stronger than a pure governance asset because Uniswap's protocol-fee mechanism now creates an explicit token-level value-capture path.

Current protocol-fee architecture routes protocol fees into TokenJar contracts and uses the fee/releaser mechanism to process accumulated assets. The resulting mechanism includes UNI burn / value-capture for UNI holders rather than simply leaving all protocol revenue at the DAO level.

Economic structure:

`Uniswap trading → protocol fees → TokenJar → fee/releaser mechanism → UNI burn / UNI value capture`

This is a real protocol-level economic linkage, but HyperLeaf should still distinguish **value capture from direct redeemable cashflow**.

Therefore raw UNI should not automatically be treated as rate-bearing Leaf collateral. The stronger future direction is a verified position that directly captures Uniswap fee economics, if/when such a position has clear accounting and exit semantics.

Preferred direction:

`Uniswap productive / fee-capture position → protocol fee value accrual → realizable value → HYPE`

Not:

`raw UNI → HYPE yield`

**UNI decision: Strong Watch / Strategic Candidate.**

### Combined HyperLeaf classification

| Asset | Productive economic link | Value capture | Preferred HyperLeaf object | Decision |
|---|---|---|---|---|
| COMP | Protocol activity is productive, but raw COMP lacks direct revenue claim | Weak / indirect | Verified Compound lending position | **Strong Watch / Strategic Watch** |
| UNI | Protocol fees create explicit token-level value capture | Medium / indirect-to-token | Verified fee-capture / productive Uniswap position | **Strong Watch / Strategic Candidate** |

The important distinction is:

> **Protocol revenue is not automatically token backing.**

HyperLeaf should only issue liabilities against a productive position whose economically realizable NAV can be verified. Burn-induced appreciation, governance treasury assets, incentives, and market-price appreciation must not be counted as backing unless there is a contractual and realizable claim.

Core invariant remains:

`totalLeafLiability <= verified economically realizable NAV of productive position`

**Final Decision: #48 — COMP + UNI: Strong Watch / Strategic Candidate (combined).** UNI is the stronger candidate because its protocol-fee architecture provides a clearer token-level value-capture path. COMP remains structurally interesting but is weaker as a standalone Leaf until a direct productive/revenue-bearing representation exists. Neither should be implemented as a raw spot-token wrapper at this stage.

## Methodology

1. Market / protocol discovery
2. Gate 0 — HyperEVM existing-asset / canonicality
3. Canonical asset identity
4. Productive position
5. Canonical backing
6. Accounting unit
7. Yield taxonomy
8. Exit topology
9. Admin / upgrade / custody trust
10. HyperEVM demand
11. HyperLeaf differentiation
12. Leaf class
13. Solvency invariant
14. ABI / fork / on-chain verification
15. Final decision
16. Implementation requirements

Core principle: productive position > spot-token wrapping. `totalLeafLiability <= verified economically realizable NAV of productive position`.
