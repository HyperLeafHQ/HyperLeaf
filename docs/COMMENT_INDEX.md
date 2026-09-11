# HyperLeaf Comment Index

Canonical asset-evaluation discussion: [issue #7](https://github.com/HyperLeafHQ/HyperLeaf/issues/7). Do not use closed PR #4 as the live index.

## Canonical evaluation series

Only formal asset evaluations receive a numbered `#NN`. Watchlist / No-Go / Already Exists / batch-screening records do not consume a new number unless explicitly promoted. Existing-number corrections are made in-place.

| # | Asset / evaluation | Preferred representation / direction | Status | Comment |
|---|---|---|---|---|
| #00 | Methodology / canonical index | Gate 0 + productive-position framework | Canonical index | [5609277559](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609277559) |
| #42 | XTZ / Tezos | Native Tezos staking position; official sTEZ only if/when mainnet activated | P1 Research / Conditional | [5639725930](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5639725930) |

See the canonical index comment for the full #01–#42 historical series and methodology.

## Non-series completed / consolidated evaluations

| Asset | Decision | Comment |
|---|---|---|
| KITE / Kite AI | Strong Watch / Strategic Candidate; agent-payment infrastructure + PoS staking; observation only until canonical KITE → HyperEVM representation, productive accounting, liquidity and exits are verified. | TBD |
| LDO | No-Go / Watchlist as standalone Leaf; prefer stETH/wstETH or productive Lido position | 5637940642 |
| BTT | P1 Research Candidate / native BTTC staking; canonical HyperEVM route required | 5637959434 |
| GNO | P1 Strategic Candidate; do not implement yet | 5638008710 |
| PI | Watchlist / No-Go; no standalone Leaf | 5630142069 |
| FLR | P1 Research Candidate; intentionally non-numbered | Historical standalone evaluation |

## KITE observation

Kite is a strong strategic watch because its product is specifically aimed at autonomous-agent identity, authorization and payments. Kite Mainnet is a PoS EVM-compatible L1 (Chain ID 2366); Agent Passport provides scoped spending controls and verifiable receipts; official tokenomics tie KITE to staking, governance, ecosystem access and planned service-commission conversion. The key HyperLeaf thesis is productive KITE staking, not spot wrapping. Mainnet contract documentation exposes native staking plus a StakingVault/LST architecture. The remaining blocker is a canonical KITE → HyperEVM route and verified cross-chain exit/accounting, so this remains observation-only.

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
