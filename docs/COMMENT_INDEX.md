# HyperLeaf Comment Index

Canonical asset-evaluation discussion: [issue #7](https://github.com/HyperLeafHQ/HyperLeaf/issues/7). Do not use closed PR #4 as the live index.

## Canonical evaluation series

Only formal asset evaluations receive a numbered `#NN`. Watchlist / No-Go / Already Exists / batch-screening records do not consume a new number unless explicitly promoted. Existing-number corrections are made in-place.

| # | Asset / evaluation | Preferred representation / direction | Status | Comment |
|---|---|---|---|---|
| #00 | Methodology / canonical index | Gate 0 + productive-position framework | Canonical index | [5609277559](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609277559) |
| #01–#41 | Existing canonical series | See canonical #00 index | Existing records | [Issue #7](https://github.com/HyperLeafHQ/HyperLeaf/issues/7) |
| #42 | XTZ / Tezos | Native Tezos staking position; official sTEZ only if/when mainnet activated | P1 Research / Conditional | [5639725930](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5639725930) |
| #43 | CFX / Conflux | Native CFX PoS productive position; bridge to HyperEVM only through a verified canonical route | Selected / P1 Research / Production Gated | [5653229999](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5653229999) |
| #44 | IMX / Immutable | Verified Immutable staking position; no spot wrapper | P1 Research / Conditional | [5653271541](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5653271541) |

## Numbering reconciliation

- **#40 = MON / shMON**, **#41 = LUNC**, **#42 = XTZ / Tezos**, **#43 = CFX / Conflux**, **#44 = IMX / Immutable**.
- Old EURC `#89` is retired and is not part of the formal evaluation series.
- MON / shMON is one consolidated record with the existing `hshMON` implementation; do not create another MON evaluation.
- LUNC legacy WLUNC has official historical Terra/Shuttle provenance, but this does **not** establish a current canonical Terra Classic → HyperEVM deployment.
- Tezos' official XTZ → Etherlink route is canonical for Etherlink, not for HyperEVM.

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

Keep Backing / Yield / Incentives / Market Price / Exit Value separate. Unverified appreciation must never create Leaf liabilities.
