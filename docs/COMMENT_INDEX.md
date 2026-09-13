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

## Non-series completed / consolidated evaluations

| Asset | Decision | Comment |
|---|---|---|
| KITE / Kite AI | Strong Watch / Strategic Candidate; agent-payment infrastructure + PoS staking; observation only until canonical KITE → HyperEVM representation, productive accounting, liquidity and exits are verified. | [5639822315](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5639822315) |
| STREAM / Streamflow | Strong Watch / Strategic Candidate; real Solana infrastructure, protocol revenue and staking/governance utility, but no current canonical STREAM → HyperEVM route and no direct claim on protocol revenue. Observation only. | [5653220142](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5653220142) |
| LDO | No-Go / Watchlist as standalone Leaf; prefer stETH/wstETH or productive Lido position | 5637940642 |
| BTT | P1 Research Candidate / native BTTC staking; canonical HyperEVM route required | 5637959434 |
| GNO | P1 Strategic Candidate; do not implement yet | 5638008710 |
| PI | Watchlist / No-Go; no standalone Leaf | 5630142069 |
| FLR | P1 Research Candidate; intentionally non-numbered | Historical standalone evaluation |

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

**Decision: Selected / P1 Research / Production Gated.** GRT is materially stronger than a normal utility/governance token because its economic role is tied directly to a productive decentralized data-service network and now has a liquid-staking representation. The next step is on-chain verification of stGRT and its complete HyperEVM exit topology before implementation.

## Methodology

1. Market / protocol discovery
2. Gate 0 — HyperEVM canonicality
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

Core rule: productive position > spot-token wrapping. `totalLeafLiability <= verified economically realizable NAV of productive position`.
