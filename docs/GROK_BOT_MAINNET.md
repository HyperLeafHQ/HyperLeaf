# Grok bot tasks — mainnet go-live

> **Status 2026-09-16: archived as a live-ops checklist.** Batches 0–1 and
> BLUAI4Y wrap + frontend cutover (`hyperleaf-web@d9b57c2`) are done.
> Live / dead addresses live in [`listings/catalog.json`](../listings/catalog.json).
> This file stays as the **deploy cookbook** for what is not live yet:
> `horder` (BATCH 4 remainder) and `hjitosol` (BATCH 5). Do not treat the
> narrative below as "do this next" unless the ticker is still unchecked.

You deploy. You do **not** redesign assets, restyle the frontend, or open a
bridge because a PR merged. Branch: **`main`**. Log every address in
issue [#7](https://github.com/HyperLeafHQ/HyperLeaf/issues/7) or a deploy comment — not a frontend rewrite.
`BATCH` is required. Wrong ticker reverts `NotThisBatch`.

Frontend copy is a **different** bot: [`GROK_BOT_FRONTEND.md`](GROK_BOT_FRONTEND.md).
Harvest notes: [`GROK_BOT_RECEIPTS.md`](GROK_BOT_RECEIPTS.md).
Solana `.so` detail: [`GROK_BOT_SOLANA.md`](GROK_BOT_SOLANA.md) (also inlined in §5).

---

## Hard rules

1. **Mainnet only.** HyperEVM 998 / Base Sepolia cannot run Labs + Horizen + Canary or the real confirmation split. Deleted testnet scripts stay deleted.
2. **Canary first.** Do not point any script at live xSQUID / stkAVNT / cbETH / gSOON / sWBERA until canary has deposited, minted, and redeemed on **8453 ↔ 999**. Then kill the canary. New addresses for real listings.
3. **Do not skip a batch.** Batch N+1 starts only after batch N’s three PR answers (below).
4. **Keys are three EOAs.** `OWNER` ≠ `GUARDIAN` ≠ `HARVESTER`. `PRIVATE_KEY` is OWNER. Converter is `LeafYieldConverter`, never an EOA. Do not leave this bot as owner.
5. **Do not `openBridge` on autopilot.** Read `listingTag`, peers, caps, ULN `getConfig` first. Then `OPEN_BRIDGE=true`.
6. **LZ fees are LayerZero’s.** UI and PR must say we do not take that fee.
7. **Do not deploy:** NestVault, HNest, HevAdapter, LeafVirtualsLockbox, LeafOmnichainHolder, LeafCreate2. Do not `setShareExit`. Do not wrap NCN VRTs (fragSOL / kySOL / ezSOL). **Leaf Market for live hNEST is a different job:** [`GROK_BOT_LEAF_MARKET.md`](GROK_BOT_LEAF_MARKET.md). Do not wait for this BATCH table. Do not deploy `LeafClaimFill` for hNEST.
8. **`main` is live + the next deploy only.** Live: BATCH 1 + `hgsoon` / `hswbera` + `bluai4y` (frontend `d9b57c2`). Next cookbook job is **`horder`** then **BATCH 5 `hjitosol`**. Do **not** merge hslisBNB as if it were the next wrap.
   - hslisBNB rate: branch **`feat/hslisbnb-rate`**
   - hsAVAX / Umbrella pins: branch **`feat/batch3-harden`**
   Do not `BATCH=3` from `main`. After smoke, merge that branch, then pin addresses.

---

## Order (this is the whole job)

| BATCH | When | Tickers | Framework | Source chain |
| ---: | --- | --- | --- | --- |
| **0** | first | `hcanary` | Toy ERC-20, L adapter, **real** ULN | Base 8453 |
| **1** | canary dead | `hxsquid` then `havnt` | Side-token L. `0x9a99b4f0`. Never `0xeab52318` | Base 8453 |
| **2** | batch 1 passed | `hgsoon` then `hswbera` | Rate L, 1% skim, 99% in receipt. **Not hcbETH** | BSC 56 / Bera 80094 |
| **3** | batch 2 passed | `hsavax` then `hstkwausdc` then **`hlbtc`** | Rate / Umbrella / LBTC 8-dec | Avax / ETH |
| **4** | batch 3 passed | `bluai4y` then `horder` | C1 lockbox + closed OFT. Market exit | BSC 56 / Arb 42161 |
| **5** | batch 4 passed **and** Store PDA exists | `hjitosol` | Solana lockbox + dest `LeafOFT`. No Rewarder | Solana 30168 → HyperEVM 999 |

jupSOL / mSOL / bnSOL / INF / hKAITO / hVIRTUALMAX / hSKY / Nest v2 are **not this job**.

---

## Confirmations (send = this chain, receive = remote)

Copying one number onto both ULNs is a DVN mismatch. Script already splits them. Check the logs.

| This chain | sendConfirms | When dest is HyperEVM, recvConfirms |
| --- | ---: | ---: |
| HyperEVM 999 | **5** | (recv = the source: 15 Base/BSC/Arb/ETH, 12 Avax, 32 Solana) |
| Base 8453 | 15 | 5 |
| BSC 56 | 15 | 5 |
| Arb 42161 | 15 | 5 |
| ETH 1 | 15 | 5 |
| Bera 80094 | 15 | 5 |
| Avax 43114 | **12** | 5 |
| Solana (program, not this script) | **32** | 5 |

Trio on every EVM we touch: **Labs + Horizen + Canary**. Sorted ascending. **Never Nethermind.**

HyperEVM `SetSecurityStack` / `WirePeers` **must** pass `ASSET=` so remote eid is not Base-by-default (`hgsoon` → 30102, `hswbera` → 30362, `hstkwausdc` → 30101, `hsavax` → 30106, `horder` → 30110, `hjitosol` → 30168).

---

## Pass / fail (every listing, including canary)

Normal: deposit → LZ → mint → (L: redeem). Then inject: wrong tag, wrong peer, closed bridge, cap, ceiling, bad selector. Each reverts, no partial state, **other listing untouched**.

After each ticker, comment on the PR:

1. Worst-case loss (cap, not unbounded)
2. Can guardian `closeBridge` in time
3. Does a broken listing contaminate another

Do not open batch N+1 until those three exist for every ticker in batch N.
