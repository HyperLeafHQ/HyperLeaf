# HyperLeaf Comment Index

Canonical asset-evaluation discussion: [issue #7](https://github.com/HyperLeafHQ/HyperLeaf/issues/7). Do not use closed PR #4 as the live index.

## Canonical evaluation series

Only formal asset evaluations receive a numbered `#NN`. Watchlist / No-Go / Already Exists / batch-screening records do not consume a new number unless explicitly promoted. Existing-number corrections are made in-place.

| # | Asset / evaluation | Preferred representation / direction | Status | Comment |
|---|---|---|---|---|
| #00 | Methodology / canonical index | Gate 0 + productive-position framework | Canonical index | [5609277559](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609277559) |
| #01–#44 | Existing canonical series | See canonical #00 index | Existing records | [Issue #7](https://github.com/HyperLeafHQ/HyperLeaf/issues/7) |
| #45 | FLOKI / Floki | FLOKI staking/lock position; convert external rewards to HYPE; no raw spot wrapper | Selected / P1 Research / Production Gated | [5653288714](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5653288714) |

## FLOKI evaluation

FLOKI is formally promoted to **#45**. The underlying FLOKI staking/locking position is the productive position. TOKEN or any other reward asset is an external reward flow and does not need to be the same token as the underlying principal.

HyperLeaf should treat the economic flow as:

`FLOKI → staking/locking position → reward asset → sell/swap → HYPE → protocol fee → Leaf yield`

The user-facing yield is therefore realized HYPE, not the identity of the reward token. Backing remains the economically realizable FLOKI principal. FLOKI market-price appreciation is not yield. Fee/burn effects are not directly redeemable backing.

Production remains gated on exact staking contract, lock/withdrawal mechanics, reward accrual and funding, admin controls, reward liquidity, swap and slippage controls, canonical HyperEVM representation, bridge custody/recovery, and solvency caps against economically realizable principal and realized HYPE proceeds.

Decision: **Selected / P1 Research / Production Gated.**

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
