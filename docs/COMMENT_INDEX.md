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

CRV and CVX should be evaluated together because Convex is a major liquid-locker layer for Curve. Curve currently generates protocol fee flows to veCRV lockers, while Convex aggregates Curve voting power and allows users to stake cvxCRV or CVX to receive platform-related rewards. Convex's current interface states that staked CVX earns a share of platform revenue distributed as cvxCRV, while locked CVX earns a different revenue share and governance/voting weight. citeturn228900search0turn228900search2

For HyperLeaf, the important distinction is representation rather than token labels:

`CRV → veCRV / Curve productive position → fees/rewards → sell/swap → HYPE`

and

`CVX → Convex stake/lock position → platform revenue / cvxCRV + incentives → sell/swap → HYPE`

Curve's 2026 fee data confirms that veCRV has a real revenue stream: May–June 2026 DEX fees were about $1.87M and $2.68M, with veCRV APR around 5.4% during that period. citeturn228900search1

However, neither raw CRV nor raw CVX should automatically be treated as a productive Leaf. The productive unit should be the verified locked/staked position that has a contractual claim to the resulting reward/revenue stream. For CRV, direct veCRV locking has a long lock horizon; Convex-style liquid-locker representations can improve composability but introduce derivative liquidity/depeg and custody assumptions. Curve itself notes that liquid-locker tokens such as cvxCRV are transferable but not directly redeemable for the underlying CRV. citeturn228900search9

**Decision: Strong Watch / Strategic Candidate — combined CRV + CVX.** No new formal number because the Curve ecosystem / scrvUSD work already exists in the formal series. Priority is to identify the best economically realizable productive representation (direct veCRV, cvxCRV, or CVX stake/lock) and verify its HyperEVM route, accounting, liquidity and exit topology before implementation.

## THETA evaluation

THETA is formally promoted to **#46** because it represents a genuine native staking productive position rather than a spot-token value proposition. Theta's current official documentation states that THETA is used to stake as a Validator or Guardian node and that staking earns newly generated TFUEL proportionally over time. The documented Guardian minimum is 1,000 THETA, with rewards distributed probabilistically at checkpoint blocks. citeturn301963search3turn301963search1turn301963search0

HyperLeaf should model the economic flow as:

`THETA → Guardian / Validator staking position → TFUEL rewards → sell/swap → HYPE → protocol fee → Leaf yield`

Backing remains the economically realizable THETA principal represented by the verified staking position. TFUEL is yield. THETA market-price appreciation is not yield and must not create additional Leaf liabilities.

Theta's current documentation also confirms that the reward stream is observable through the staking wallet / explorer and that Guardian rewards are awarded every 100 blocks (~10 minutes) using a probabilistic, stake-weighted process. This makes realized TFUEL a suitable accounting input; HyperLeaf should not account from a headline APR. citeturn301963search0turn301963search2

The main production gate is the complete exit topology:

`HyperEVM Leaf → productive THETA staking position → verified THETA exit / unstake → canonical destination representation`

Theta's Metachain architecture is EVM-compatible, but EVM compatibility alone does not establish a canonical HyperEVM productive representation. citeturn301963search11

Therefore the preferred design is a **verified native THETA staking position adapter**, not a raw THETA bridge/wrapper. Production requires verification of the exact staking contract(s), custody model, deposit/delegation, withdrawal and unbonding mechanics, reward beneficiary, canonical THETA/TFUEL route to HyperEVM, bridge recovery/security, HyperEVM liquidity, and safe TFUEL→HYPE liquidation.

The adapter must also prevent double-counting pending versus claimed TFUEL and cap Leaf liabilities against economically realizable THETA principal plus realized reward proceeds.

**Decision: Selected / P1 Research / Production Gated.** THETA is a strong productive-position candidate, but implementation remains blocked until the full native-staking → HyperEVM → exit topology is verified on-chain.

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
