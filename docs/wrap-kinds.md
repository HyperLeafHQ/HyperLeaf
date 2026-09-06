# Wrap kinds

Three listings. Never mix exits on one pair. Never turn a live C1 into C2.

| Kind | Source | HyperEVM | Exit | Ticker |
| ---- | ------ | -------- | ---- | ------ |
| L | `LeafOFTAdapter` | `LeafOFT` | Instant inner receipt | `h` + asset (`hKAITO`) |
| C1 | `LeafInboundLockbox` | `LeafClosedOFT` | Sell on HyperEVM only | lock in symbol (`BLUAI4Y`) |
| C2 | `LeafRedeemQueue` | `LeafOFT` | Burn, wait, `claim` on source | lock in symbol if useful (`VIRTUAL30D`) |

## C1 example: BLUAI4Y

- Inner: BLUAI on BSC `0xed9Ae3DEF8d6F052971Bb8b6d1975FF267Cf9aaD`
- HyperEVM name: `Hyperliquid BLUAI 4Year`
- HyperEVM symbol: `BLUAI4Y`
- `send` on `LeafClosedOFT` reverts `ExitViaMarketOnly`
- Reverse message on the lockbox reverts `InboundOnly`
- UI must say: cannot redeem from the protocol; selling is the only exit; expect a discount

`lockSeconds` on the OFT is a label (4 * 365 days). The lockbox does **not** call Bluwhale stake for you. Wiring their 4y contract is a later adapter.

## C2

`redeemDelay` is immutable and must be >= the underlying unstake. Mature `claim` still works while paused.

## Naming

- L: `hKAITO`, `hSAVAX`, `hSHMON`
- C1/C2: `BLUAI4Y`, `BONK30D` — duration in the ticker so a Hyperliquid book is not confused with spot
