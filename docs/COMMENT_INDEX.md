# HyperLeaf Comment Index

Canonical asset-evaluation discussion: [issue #7](https://github.com/HyperLeafHQ/HyperLeaf/issues/7). Do not use closed PR #4 as the live index.

## Canonical evaluation series

Only formal asset evaluations receive a numbered `#NN`. Watchlist / No-Go / Already Exists / batch-screening records do not consume a new number unless explicitly promoted. Existing-number corrections are made in-place.

| # | Asset / evaluation | Preferred representation / direction | Status | Comment |
|---|---|---|---|---|
| #00 | Methodology / canonical index | Gate 0 + productive-position framework | Canonical index | [5609277559](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609277559) |
| #01–#41 | Existing canonical series | See canonical #00 index | Existing records | [Issue #7](https://github.com/HyperLeafHQ/HyperLeaf/issues/7) |
| #42 | XTZ / Tezos | Native Tezos staking position; official sTEZ only if/when mainnet activated | P1 Research / Conditional | [5639725930](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5639725930) |
| #43 | CFX / Conflux | Native CFX PoS productive position; bridge to HyperEVM only through a verified canonical route | Selected / P1 Research / Production Gated | [PLACEHOLDER](https://github.com/HyperLeafHQ/HyperLeaf/issues/7) |

## Numbering reconciliation

- **#40 = MON / shMON**, **#41 = LUNC**, **#42 = XTZ / Tezos**, **#43 = CFX / Conflux**.
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

## CFX evaluation

CFX qualifies for a formal HyperLeaf evaluation because it has a native, protocol-level productive position: Conflux PoS staking. Conflux's official documentation states that CFX staking earns PoS rewards, with a normal 13-day lock after staking and a 1-day unlocking period after unstake; early exit can extend the total waiting period up to 14 days.

Conflux has two execution spaces: Core Space, where native CFX staking and PoS functionality live, and eSpace, which is EVM-compatible. The Core/eSpace split is an important accounting and custody consideration for HyperLeaf. Conflux provides an official CrossSpace mechanism for moving CFX between Core and eSpace, but an unstaked eSpace balance is not itself a staking position.

Cross-chain canonicality is materially stronger than many candidates: Conflux publicly announced Stargate support for CFX transfers involving Conflux eSpace, Ethereum, HyperEVM and Kaia in November 2025. This establishes an operational CFX → HyperEVM route, but not a native Hyperliquid canonical asset deployment. Hyperliquid documentation also permits external bridges and permissionless EVM token deployments, so the exact HyperEVM token, custody and bridge route must still be verified.

Preferred architecture:

`CFX → Core PoS staking position → verified exit/unlock → canonical bridge route → HyperEVM Leaf`

or, once a mature canonical staking receipt exists:

`CFX → canonical rate-bearing staking receipt → HyperEVM Leaf`

Do not treat unstaked eSpace CFX as a staked productive position. Do not capitalize CFX market-price appreciation as yield. Staking rewards must be separated from inflation, incentives, market price and bridge liquidity.

CFX has meaningful protocol utility across gas, storage, governance and PoS participation. Its monetary model is inflationary from PoW and PoS issuance, with protocol burn mechanisms; accounting must distinguish staking reward accrual from broader token-supply dilution.

Decision: **Selected / P1 Research / Production Gated.** Production is blocked until HyperLeaf verifies exact Core-space staking custody, reward accrual/accounting, validator/slashing behavior, Core → eSpace → HyperEVM exit topology, exact HyperEVM token contract and bridge controls, bridge failure/recovery procedures, and capped solvency limits against verified economically realizable NAV.

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

Keep **Backing / Yield / Incentives / Market Price / Exit Value** separate. Unverified appreciation must never create Leaf liabilities.
