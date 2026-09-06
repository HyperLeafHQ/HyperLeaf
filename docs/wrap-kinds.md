# Wrap kinds

Three listings. Never mix exits on one pair. Never turn a live C1 into a C2.

HyperLeaf is infrastructure for liquid staking on HyperEVM: introduce the asset, keep the extra income of the source position.

| Kind | Source | HyperEVM | Exit | Ticker |
| ---- | ------ | -------- | ---- | ------ |
| L | `LeafOFTAdapter` | `LeafOFT` | Instant inner receipt | `hKAITO`, `hxSQUID`, `hwstETH`, `hsAVAX`, `hshMON` |
| C1 | `LeafInboundLockbox` | `LeafClosedOFT` | Sell on HyperEVM only | `VIRTUAL4Y`, `BONK12M`, `BLUAI4Y` |
| C2 | `LeafRedeemQueue` | `LeafOFT` | Burn, wait, `claim` | `hMET` |

Deploy: `docs/testnet-deploy.md`. Ids: `src/lz/AssetCatalog.sol`.

## Fees

Default: 1% of newly accrued inner yield stays as inner (`harvest`).

**HYPE convert mode** (`setConvertYieldToHype(true)`): surplus is pulled by the
harvester, swapped to HyperEVM WHYPE, then `LeafHypeRewarder.notify` — 1%
protocol / 99% claimable HYPE. Redeem of principal is 1:1. See `docs/HYPE_YIELD.md`.


## Queue

1. **hKAITO** (L, Base)
2. **hxSQUID** (L, Base)
3. **hwstETH** (L, Base) — pair with Unit uETH
4. **VIRTUAL4Y** (C1, Base)
5. **hsAVAX** (L, Avalanche) — pair with Unit uAVAX
6. **BONK12M** (C1, Solana — testnet mock only)
7. **hMET** (C2, Solana — testnet mock only)
8. **BLUAI4Y** (C1, BSC)
9. **hshMON** (L, Monad — pending LZ)

hNEST is native HyperEVM, not this wrap.
