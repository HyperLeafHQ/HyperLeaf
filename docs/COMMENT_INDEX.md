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

FLOKI is formally promoted to **#45**. Floki's current materials describe a staking/locking program in which users stake FLOKI and receive TOKEN rewards, alongside an ecosystem spanning Valhalla, TokenFi, FlokiFi, Floki Name Service and the Trading Bot.

For HyperLeaf, the identity of the reward token is not the key criterion. The underlying FLOKI staking/locking position is the productive position. TOKEN or any other reward asset is an external reward flow. Once that reward is verifiably accrued and liquid, HyperLeaf can sell/swap it into HYPE; the resulting HYPE is the user-facing yield after the applicable protocol fee.

Accounting therefore separates:

- **Backing:** locked FLOKI principal actually controlled by the staking position.
- **Reward flow:** TOKEN or other assets produced by the position.
- **HYPE yield:** realized reward proceeds after conversion into HYPE and protocol fee.
- **Market price:** FLOKI price movement, which is not yield.
- **Value capture:** fee/burn effects, which are not direct redeemable revenue claims.
- **Exit value:** what can actually be withdrawn and transferred through the verified bridge route.

Preferred architecture:

`FLOKI → verified staking/locking position → reward asset → swap/sell → HYPE → protocol fee → Leaf yield`

Do not build a raw 1:1 FLOKI spot wrapper and call the reward token FLOKI yield. Production still requires verification of the staking contract, lock/withdrawal rules, reward accrual and funding, admin controls, reward liquidity, swap/slippage controls, canonical HyperEVM representation, bridge custody/failure recovery, and solvency caps against economically realizable principal and realized HYPE proceeds.

Decision: **Selected / P1 Research / Production Gated.** FLOKI qualifies because its staking/locking position produces a real, monetizable reward stream. The relevant product property is therefore productive reward generation, not whether the reward token itself is FLOKI.

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
