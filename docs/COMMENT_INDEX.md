# Where to read

Asset evaluations live on **issue [#7](https://github.com/HyperLeafHQ/HyperLeaf/issues/7)**. Do not hunt closed [PR #4](https://github.com/HyperLeafHQ/HyperLeaf/pull/4).

Canonical lists:

- Listings: [ROADMAP.md](ROADMAP.md) + [listings/catalog.json](../listings/catalog.json)
- Pipeline + eval series: [#7](https://github.com/HyperLeafHQ/HyperLeaf/issues/7)
- Trust keys: [#6](https://github.com/HyperLeafHQ/HyperLeaf/issues/6)
- Solana runtime: [#20](https://github.com/HyperLeafHQ/HyperLeaf/issues/20)

Register: [5609229978](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609229978)

**Luna eval ≠ verified.** Official docs + RPC + LZ metadata win. Verified rows below override the Luna note.

## Luna series → verified (issue #7)

| Luna | Research note | Verified | Decision |
| --- | --- | --- | --- |
| #00 | [5609277559](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609277559) method | keep | method |
| #01 | [5609279073](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609279073) USD1 / HertzFlow | `hHLV` only `0xeeA83A77…`. Never USD1. `docs/STABLE_VAULTS.md` · `feat/stables` | watch |
| #02 | [5609280771](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609280771) GRAM → tsTON | still watch. Need TON LZ + receipt mint | watch |
| #03 | [5609282039](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609282039) HBAR / HBARX | Stader HTS `0x0000…cba44`. `docs/HBAR.md` · `feat/hbarx` | later |
| #04 | [5609283334](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609283334) NEAR / stNEAR | [5621672666](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5621672666) Aurora STNEAR 24-dec. `docs/STNEAR.md` · `feat/stnear` | later (OFT 24-dec) |
| #05 | [5609285169](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609285169) USDG | steakUSDG later. Never USDG | later |
| #06 | [5609286867](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609286867) TAO | parked. Tensorplex sunset. `docs/TAO.md` | parked |
| #07 | [5609288243](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609288243) PYUSD | later kV-PYUSD / Kamino after Jito. `docs/PYUSD.md` | later (Sol) |
| #08 | [5609290174](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609290174) M / MemeCore | [5621942041](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5621942041) X$M unpinned. LZ 30466 no Horizen/Canary. `docs/MEMECORE.md` · `feat/memecore` | watch |
| #09 | [5609262492](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609262492) Bitway USDT | BTWUSDT later. Never raw USDT | later |
| #10 | [5609263693](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609263693) bwBTW | watch | watch |
| #11 | [5609265033](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609265033) sTRX | watch until LZ TRON | watch |
| #12 | [5609266200](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609266200) hLINK | watch. Pool full | watch |
| #13 | [5609267997](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609267997) hDAI | Gauntlet shares. Cap 100k. Never DAI | later |
| #14 | [5609270716](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5609270716) slisBNB | after hgSOON. Never BNB / 7d unstake | batch 2b |

## Verified after Luna (not in #00–#14)

| Asset | Comment / branch | Decision |
| --- | --- | --- |
| hsGHO | [5621505679](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5621505679) · `docs/SGHO.md` · `feat/sgho` | later. Wrap sGHO only, not App 6% |
| hsUSDf | `docs/SUSDF.md` · `feat/susdf` | later. Wrap Falcon sUSDf only, not USDf / FF |
| hsFF | `docs/SFF.md` · `feat/sff` | later. Flexible sFF only. Never Prime |
| hsSUI | `docs/SSUI.md` · `feat/ssui` | later after Jito. Wrap SpringSui sSUI only |
| JUP / jupSOL | catalog `hjup` skip · `hjupsol` later-after-msol | **skip proxy JUP**. jupSOL after mSOL |
| hsKCS | `docs` skip · `feat/kcs` | skip. ~3k sKCS, no LZ KCC |
| hsPOL | `feat/hspol` | later. Official sPOL, not child |
| stATOM | Axelar ~8 tokens | parked. Don't copy Axelar |
| asBNB | after hslisBNB | later. Aster Earn on BSC. Never $ASTER ve |
| sUSDf / sFF / TUSD / STX | Luna [5621645359](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5621645359) / [5621648308](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5621648308) / [5621676207](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5621676207) / [5621742149](https://github.com/HyperLeafHQ/HyperLeaf/issues/7#issuecomment-5621742149) | Luna research only. Not RPC-verified yet |

New memos: next `#NN` on **#7**, then ROADMAP / catalog. No tmp issues. No new eval comments on #4. **Do not merge unverified listings to `main`.**

## Deploy / audit (historical, PR #4)

| Kind | Comment | What |
| --- | --- | --- |
| Deploy | [5607916305](https://github.com/HyperLeafHQ/HyperLeaf/pull/4#issuecomment-5607916305) | hCANARY v2 PASS |
| Deploy | [5609220716](https://github.com/HyperLeafHQ/HyperLeaf/pull/4#issuecomment-5609220716) | Batch 1 v2: hAVNT PASS, hxSQUID redeem OOG |
| Deploy | hxSQUID v3 | SOURCE `0x13E3…0d25` / OFT `0x78B6…4DFc`. Redeem PASS. v2 `0x6586…` abandoned |
| Deploy | [5606320087](https://github.com/HyperLeafHQ/HyperLeaf/pull/4#issuecomment-5606320087) | Leaf Market live |
| Deploy | [5606511931](https://github.com/HyperLeafHQ/HyperLeaf/pull/4#issuecomment-5606511931) | Gate `0xE1b8…` / abandon `0xB4C43…` |
| Audit | [5605875989](https://github.com/HyperLeafHQ/HyperLeaf/pull/4#issuecomment-5605875989) | Gate HEAD |
| Audit | [5588977985](https://github.com/HyperLeafHQ/HyperLeaf/pull/4#issuecomment-5588977985) | Solana spec (open in #20) |

Abandoned: PR #22 (`7cd3134` Gate). hxSQUID v2 `0x6586…d206` (OOG). Do not merge leftover wrap branches.
