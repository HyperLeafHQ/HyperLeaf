# Wrap kinds

`L` / `C1` / `C2` stay on GitHub. Public UI copy: `docs/GROK_BOT_FRONTEND.md`.

Three listings. Never mix exits on one pair. Never turn a live C1 into a C2.

**Rate-bearing L (hcbETH, hgSOON, hsAVAX, later same class):** `setRateKind` + `setRetainRateYield(true)`. Wrap and redeem **settle the 1% first** (flush to converter if convert is on; book only if halted — mint/redeem stay live). Harvest pulls **1% of** `(lastAccounted * (rate - lastRate)) / rate`. **99% stays in the lockbox.** New deposits mint at post-fee NAV, so they are not taxed for a move they missed. Redeemers cannot skip the 1% by leaving before a keeper harvest. Do not swap inside wrap. Donations are not yield.

**Umbrella L (hstkwaUSDC):** same 1% rate skim via `convertToAssets` **plus** `pokeRewards` → `RewardsController.claimAllRewards([inner], lockbox)` (`0xbb492bf5`). Target is the controller, never the StakeToken. Never `cooldown`.

xSQUID stays 1:1 because QUID is a different ERC-20 — that is Rewarder, not share-price (`docs/YIELD_OWNERSHIP.md`). **hgSOON** uses `ConvertToAssets` + `retainRateYield` (cbETH-class 1% skim). hsWBERA / Morpho stay yield-in-share until their row opts in.


HyperLeaf is infrastructure for liquid staking on HyperEVM: introduce the asset, keep the extra income of the source position.

| Kind | Source | HyperEVM | Exit | Ticker |
| ---- | ------ | -------- | ---- | ------ |
| L | `LeafOFTAdapter` | `LeafOFT` | Instant inner receipt | `hKAITO`, `hxSQUID`, `hcbETH`, `hwstETH`, `hsAVAX`, `hshMON` |
| C1 | `LeafInboundLockbox` / `LeafVirtualsLockbox` | `LeafClosedOFT` | Sell on HyperEVM only | `hVIRTUALMAX`, `BONK12M`, `BLUAI4Y`, `hORDER` |
| C2 | `LeafRedeemQueue` | `LeafOFT` | Burn, wait, `claim` | `hMET` |

Deploy: `docs/testnet-deploy.md`. Ids: `src/lz/AssetCatalog.sol`.

## Fees

Default: 1% of newly accrued inner yield stays as inner (`harvest`).

**HYPE convert** (`docs/HYPE_YIELD.md`):

1. Anyone: `pokeClaim` / farm `harvest(lockbox)` — claim into the lockbox, pay gas, no swap.
2. Keeper weekly: `pullYield` QUID / extra BLUAI / airdrops → WHYPE → `notify` 1%/99%. **cbETH:** pull **1% of rate surplus** only; 99% stays in the box.
3. L never `pullYield` sKAITO or xSQUID. C1 BLUAI4Y may pull extra inner BLUAI only. Rate L may pull **only** the `exchangeRate` / `convertToAssets` surplus.




## Queue

1. **hxSQUID** (L, Base)
2. **hcbETH** (L, Base)
3. **hveAERO** (ve-NFT, Base — later)
4. **hsWBERA** (L, Berachain) — wrap sWBERA. Never 4626 `withdraw`/`redeem` (those queue 7d)

**Morpho vault shares (L family):** wrap the **ERC-4626 vault token**, not USDC/USDG, not a Morpho Blue market position. Blue supply is address-keyed — that is ORDER-class, skip. Each vault is its own listing (curator + markets ≠ shared backing). Never `deposit`/`mint`/`withdraw`/`redeem` on the vault. Yield in `convertToAssets`. Base and Robinhood both have LZ. Do not auto-list every Morpho vault; each needs a SOLVENCY row.
5. **hAEVO** (C1, Ethereum)
6. **hJupSOL** (L, Solana)
7. **hANSEM** (L, Solana, ansem.io)
8. **hwstETH** (L, Ethereum) — later, own ticker

**Parked:** **hSKY** — stake-only (~4%) strips LockStake borrow. Min 30k USDS / ~1.44M SKY. If revived: C1 only-in, disclose liquidation. **hGMX** — stake yield frozen until $90; GLP V1 retired 2025-07-16. **hUNCX** — stake rewards + buybacks paused 2026-08-21; locker fees continue, not paid to stakers. **hSNX** — 420 staking closed Jun 2026; SIP-423 Phase 4 deferred. **hveUP** — veUP NFT on Robinhood Chain; wait NFT lockbox (with hveAERO). Never wrap liquid UP.

**Hold:** **hstkAAVE** — Safety Module is legacy; Umbrella is the live backstop. Do not tokenize AAVE governance until (1) stkAAVE still exists after Umbrella is mature, (2) voting power is a protocol delegate not the hToken, (3) HyperEVM has a real AAVE spot gap. **aave-umbrella** is a different listing (risk tranche), not hAAVE.

Blocked until omnichain holder: **hKAITO**, **hVIRTUALMAX**.

hNEST is native HyperEVM, not this wrap.
