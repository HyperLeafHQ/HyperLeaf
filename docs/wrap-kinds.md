# Wrap kinds

Three listings. Never mix exits on one pair. Never turn a live C1 into a C2.

HyperLeaf is infrastructure for liquid staking on HyperEVM: introduce the asset, keep the extra income of the source position.

| Kind | Source | HyperEVM | Exit | Ticker |
| ---- | ------ | -------- | ---- | ------ |
| L | `LeafOFTAdapter` | `LeafOFT` | Instant inner receipt | `hKAITO`, `hxSQUID`, `hcbETH`, `hwstETH`, `hsAVAX`, `hshMON` |
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

1. **hxSQUID** (L, Base)
2. **hcbETH** (L, Base)
3. **hveAERO** (ve-NFT, Base — new lockbox)
4. **hLSSKY** (C1, Ethereum — urn lockbox; research-next)
5. **hsWBERA** (L, Berachain — LZ)
6. **hAEVO** (C1, Ethereum)
7. **hGMX** (C1, Arbitrum)
8. **hJupSOL** (L, Solana)
9. **hANSEM** (L, Solana, ansem.io)
10. **hwstETH** (L, Ethereum) — later, own ticker

**Hold:** **hstkAAVE** — Safety Module is legacy; Umbrella is the live backstop. Do not tokenize AAVE governance until (1) stkAAVE still exists after Umbrella is mature, (2) voting power is a protocol delegate not the hToken, (3) HyperEVM has a real AAVE spot gap. **aave-umbrella** is a different listing (risk tranche), not hAAVE.

Blocked until omnichain holder: **hKAITO**, **hVIRTUALMAX**.

hNEST is native HyperEVM, not this wrap.
