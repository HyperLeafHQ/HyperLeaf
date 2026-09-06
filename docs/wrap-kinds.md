# Wrap kinds

Three listings. Never mix exits on one pair. Never turn a live C1 into a C2.

HyperLeaf is infrastructure for liquid staking on HyperEVM: introduce the asset, keep the extra income of the source position.

| Kind | Source | HyperEVM | Exit | Ticker |
| ---- | ------ | -------- | ---- | ------ |
| L | `LeafOFTAdapter` | `LeafOFT` | Instant inner receipt | `hKAITO`, `hxSQUID`, `hwstETH`, `hsAVAX`, `hshMON` |
| C1 | `LeafInboundLockbox` / `LeafVirtualsLockbox` | `LeafClosedOFT` | Sell on HyperEVM only | `hVIRTUALMAX`, `BONK12M`, `BLUAI4Y` |
| C2 | `LeafRedeemQueue` | `LeafOFT` | Burn, wait, `claim` | `hMET` |

Deploy: `docs/testnet-deploy.md`. Ids: `src/lz/AssetCatalog.sol`.

## Fees

Default: 1% of newly accrued inner yield stays as inner (`harvest`).

**HYPE convert** (`docs/HYPE_YIELD.md`):

1. Anyone: `LeafCallRewardSource.harvest(lockbox)` — claim into the lockbox, pay gas, no swap.
2. Keeper weekly: `pullYield` QUID / extra BLUAI / airdrops → WHYPE → `notify` 1%/99%.
3. L never `pullYield` sKAITO or xSQUID. C1 BLUAI4Y may pull extra inner BLUAI only.




## Queue

1. **hKAITO** (L, Base)
2. **hxSQUID** (L, Base)
3. **hwstETH** (L, Base) — pair with Unit uETH
4. **hVIRTUALMAX** (C1, Base, Virtuals Auto Max-lock)
5. **hsAVAX** (L, Avalanche) — pair with Unit uAVAX
6. **BONK12M** (C1, Solana — testnet mock only)
7. **hMET** (C2, Solana — testnet mock only)
8. **BLUAI4Y** (C1, BSC)
9. **hshMON** (L, Monad — pending LZ)

hNEST is native HyperEVM, not this wrap.
