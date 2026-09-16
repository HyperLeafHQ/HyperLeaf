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
