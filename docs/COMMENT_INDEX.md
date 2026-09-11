# Where to read

Asset evaluations live on **issue [#7](https://github.com/HyperLeafHQ/HyperLeaf/issues/7)** (they said “PR 7”). Do not hunt closed [PR #4](https://github.com/HyperLeafHQ/HyperLeaf/pull/4).

Canonical lists:

- Listings: [ROADMAP.md](ROADMAP.md) + [listings/catalog.json](../listings/catalog.json)
- Pipeline + eval series: [#7](https://github.com/HyperLeafHQ/HyperLeaf/issues/7)
- Trust keys: [#6](https://github.com/HyperLeafHQ/HyperLeaf/issues/6)
- Solana runtime: [#20](https://github.com/HyperLeafHQ/HyperLeaf/issues/20)

Register: [5609229978](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609229978)

## Evaluation series (issue #7)

Only **formal asset evaluations** receive a numbered `#NN` entry. Rank-screening batches, watchlist/no-go items, and “already evaluated / already exists” skips are indexed separately and do not consume a new formal evaluation number.

| ID | Comment | Asset |
| --- | --- | --- |
| #00 | [5609277559](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609277559) | method |
| #01 | [5609279073](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609279073) | USD1 / HertzFlow |
| #02 | [5609280771](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609280771) | GRAM → tsTON |
| #03 | [5609282039](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609282039) | HBAR / HBARX |
| #04 | [5609283334](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609283334) | NEAR / stNEAR |
| #05 | [5609285169](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609285169) | USDG |
| #06 | [5609286867](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609286867) | TAO / Root Stake |
| #07 | [5609288243](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609288243) | PYUSD |
| #08 | [5609290174](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609290174) | M / MemeCore |
| #09 | [5609262492](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609262492) | Bitway USDT |
| #10 | [5609263693](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609263693) | bwBTW |
| #11 | [5609265033](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609265033) | sTRX |
| #12 | [5609266200](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609266200) | hLINK |
| #13 | [5609267997](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609267997) | hDAI / Gauntlet |
| #14 | [5609270716](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609270716) | slisBNB |
| #89 | [5623789248](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5623789248) | EURC / Circle Euro Coin |

### Latest batch screening / status updates

**Batch #89–#91, 2026-09-11:** [index update 5623791940](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5623791940)

| Asset | Classification | Index treatment |
| --- | --- | --- |
| EURC | **Selected — P2 research / capped pilot** | Formal evaluation **#89**; preferred position = Base Steakhouse Prime EURC `steakEURC` ERC-4626; never raw EURC; never EURCV |
| SPX6900 / SPX | **No-Go / meme** | Watchlist / consolidated rejected pool; **no standalone formal report** |
| VIRTUAL | **Already evaluated / skip** | Do not create another evaluation; existing `hVIRTUALMAX` remains the canonical prior evaluation, currently blocked by CREATE2 holder constraints |
| PONS | **Watchlist / No-Go** | Consolidated watchlist; buyback/burn is token-level value capture, not Leaf yield; no standalone formal report |

The ranking number is **not** the HyperLeaf evaluation number. VIRTUAL being rank #91 and PONS rolling to rank #92 does not create `#90/#91` formal evaluation records.

### Additional recent standalone evaluation

- **PI / Pi Network** — [5618970421](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5618970421) (English duplicate: [5630142069](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5630142069)) — **Watchlist / No-Go**, no formal Leaf candidate, no hPI deployment plan. This is a standalone research conclusion but intentionally remains outside the numbered formal `#NN` series because it is a rejection/watchlist item.

### Duplicate-language comments

The English comments that explicitly supersede Chinese originals are mirrors, not new evaluations:

- EURC English mirror: [5630151972](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5630151972) → supersedes [5623789248](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5623789248)
- Batch index English mirror: [5630154906](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5630154906) → supersedes [5623791940](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5623791940)
- PI English mirror: [5630142069](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5630142069) → supersedes [5618970421](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5618970421)

## Product / wrap-up memo

[5630137867](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5630137867) is the English wrap-up mirror of the product memo [5609846444](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609846444). It is **not an asset evaluation** and should not be counted in the evaluation series.

## Deploy / audit (historical, PR #4)

| Kind | Comment | What |
| --- | --- | --- |
| Deploy | [5607916305](https://github.com/HyperLeafHQ/HyperLeaf/pull/4#issuecomment-5607916305) | hCANARY v2 PASS |
| Deploy | [5609220716](https://github.com/HyperLeafHQ/HyperLeaf/pull/4#issuecomment-5609220716) | Batch 1 v2: hAVNT PASS, hxSQUID redeem OOG |
| Deploy | [5606320087](https://github.com/HyperLeafHQ/HyperLeaf/pull/4#issuecomment-5606320087) | Leaf Market live |
| Deploy | [5606511931](https://github.com/HyperLeafHQ/HyperLeaf/pull/4#issuecomment-5606511931) | Gate `0xE1b8…` / abandon `0xB4C43…` |
| Audit | [5605875989](https://github.com/HyperLeafHQ/HyperLeaf/pull/4#issuecomment-5605875989) | Gate HEAD |
| Audit | [5588975985](https://github.com/HyperLeafHQ/HyperLeaf/pull/4#issuecomment-5588975985) | Solana spec (open in #20) |

Abandoned: PR #22 (`7cd3134` Gate). hxSQUID v2 `0x6586…d206` (OOG). Do not merge leftover wrap branches.
