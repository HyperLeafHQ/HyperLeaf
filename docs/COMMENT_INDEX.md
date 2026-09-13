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

CFX qualifies for a formal HyperLeaf evaluation because it has a native, protocol-level productive position: Conflux PoS staking. Conflux's official documentation states that CFX staking earns PoS rewards, and current staking mechanics include a 13-day locking period followed by a normal 1-day unlocking period after unstake; early unstake can extend the period up to 14 days. CFX therefore represents a real productive consensus position rather than a passive spot balance.

Conflux has two execution spaces: Core Space, where native CFX staking and PoS functionality live, and eSpace, which is EVM-compatible. The Core/eSpace split is an important accounting and custody consideration for HyperLeaf. Conflux provides an official CrossSpace mechanism for moving CFX between Core and eSpace, but a CFX balance on eSpace is not itself a staking position.

Cross-chain canonicality is materially stronger than for many candidates: Conflux publicly announced Stargate support for CFX transfers involving Conflux eSpace, Ethereum, HyperEVM and Kaia in November 2025. This proves an operational CFX → HyperEVM bridge route exists, but it is still an external omnichain route rather than a native Hyperliquid canonical asset deployment. Hyperliquid documentation likewise permits external bridges and permissionless EVM token deployments. Therefore the HyperEVM representation must be verified at contract, custody, bridge and exit layers before production.

The preferred HyperLeaf architecture is therefore:

`CFX → Core PoS staking position → verified exit/unlock → canonical bridge route → HyperEVM Leaf`

or, where a mature canonical staking receipt becomes available:

`CFX → canonical rate-bearing staking receipt → HyperEVM Leaf`

Do not back a Leaf with unstaked eSpace CFX while representing it as though the underlying position is staked. Do not capitalize CFX price appreciation as yield. Staking rewards must be separated from market price, inflation, incentives and bridge liquidity.

CFX has meaningful protocol-level utility: gas, storage, governance and PoS participation. Current official materials also document ongoing inflation from PoW and PoS issuance and corresponding burn mechanisms. This means NAV/accounting must explicitly distinguish staking reward accrual from dilution of the broader token supply.

Decision: **Selected / P1 Research / Production Gated.** The asset is support-worthy, but production is blocked until HyperLeaf verifies: (1) exact Core-space staking custody model, (2) reward accrual/accounting, (3) validator/slashing/force-retire behavior, (4) the full CFX Core → eSpace → HyperEVM exit topology, (5) the exact HyperEVM token contract and bridge controls, (6) bridge failure/recovery procedures, and (7) capped solvency limits against verified economically realizable NAV.

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
