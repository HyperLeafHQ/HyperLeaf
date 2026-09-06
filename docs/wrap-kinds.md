# Wrap kinds

Three listings. Never mix exits on one pair. Never turn a live C1 into C2.

| Kind | Source | HyperEVM | Exit | Ticker |
| ---- | ------ | -------- | ---- | ------ |
| L | `LeafOFTAdapter` | `LeafOFT` | Instant inner token/receipt | `h` + asset (`hKAITO`, `hQUID`) |
| C1 | `LeafInboundLockbox` | `LeafClosedOFT` | Sell on HyperEVM only | lock in symbol (`VIRTUAL4Y`, `BONK12M`, `BLUAI4Y`) |
| C2 | `LeafRedeemQueue` | `LeafOFT` | Burn, wait, `claim` on source | `hMET` (unstake exists) |

## Queue

1. **hKAITO** (L, Base) - current PR
2. **hQUID** (L, Base) - Squid $QUID. Stake has **no lock**. We just introduce QUID to HyperEVM: lock QUID, mint `hQUID`, redeem QUID. Same contracts as sKAITO.
3. **VIRTUAL4Y** (C1, Base) - pairs with Unit `uVIRTUAL`. ve is not a liquid receipt.
4. **BONK12M** (C1, Solana) - 12-month Bonk Rewards lock. Needs Solana lockbox. Pairs with `uBONK`.
5. **hMET** (C2, Solana) - Meteora, unstake ~21d. Needs Solana lockbox + queue.
6. **BLUAI4Y** (C1, BSC) - high risk, last among these.

## C1 naming

- `VIRTUAL4Y` = Hyperliquid VIRTUAL 4Year
- `BONK12M` = Hyperliquid BONK 12Month
- `BLUAI4Y` = Hyperliquid BLUAI 4Year

UI: cannot redeem from the protocol; selling is the only exit; expect a discount vs spot/Unit.

## L: QUID

Not a closed ticker. Unstake on Squid is anytime, so wrapping their stake position adds nothing. Wrap **QUID**, instant redeem **QUID**. Yield stays on stake.squidrouter.com if the user wants it.

## C2: MET

Do not put MET in C1. Unstake exists. `redeemDelay` >= Meteora unbonding (~21d). Mature `claim` still works while paused.

Solana listings wait for a Solana lockbox. Do not fake them on the EVM Adapter.
