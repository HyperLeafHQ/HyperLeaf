# Wrap kinds

Three listings. Never mix exits on one pair. Never turn a live C1 into C2.

HyperLeaf is infrastructure for liquid staking on HyperEVM: introduce the asset, keep the extra income of the source position.

| Kind | Source | HyperEVM | Exit | Ticker |
| ---- | ------ | -------- | ---- | ------ |
| L | `LeafOFTAdapter` | `LeafOFT` | Instant inner receipt | `h` + asset (`hKAITO`, `hxSQUID`) |
| C1 | `LeafInboundLockbox` | `LeafClosedOFT` | Sell on HyperEVM only | lock in symbol (`VIRTUAL4Y`, `BONK12M`, `BLUAI4Y`) |
| C2 | `LeafRedeemQueue` | `LeafOFT` | Burn, wait, `claim` on source | `hMET` (unstake exists) |

## Fees

1% of **newly accrued** staking yield to `feeRecipient` (`YIELD_FEE_BPS = 100`). No protocol fee on lock, unlock, or claim. Users pay LayerZero + gas.

- L / C2: remaining 99% goes to holders via pro-rata redeem / ticket.
- C1: remaining 99% stays as extra backing (no protocol redeem).
- Repeat `harvest` with no new yield is a no-op.

Side-token rewards (e.g. QUID on an xSQUID lockbox): 1% harvested, 99% stays in the lockbox until a rewarder exists.

## Queue

1. **hKAITO** (L, Base) — current PR
2. **hxSQUID** (L, Base) — wrap xSQUID receipt, redeem xSQUID. User who wants QUID uses Squid cooldown/redeem.
3. **VIRTUAL4Y** (C1, Base) — ve is not a liquid receipt. Locked form on HyperEVM.
4. **BONK12M** (C1, Solana) — 12-month Bonk Rewards lock. Needs Solana lockbox.
5. **hMET** (C2, Solana) — Meteora, unstake ~21d. Needs Solana lockbox + queue.
6. **BLUAI4Y** (C1, BSC) — high risk, last among these.

## C1 naming

- `VIRTUAL4Y` = Hyperliquid VIRTUAL 4Year
- `BONK12M` = Hyperliquid BONK 12Month
- `BLUAI4Y` = Hyperliquid BLUAI 4Year

UI: cannot redeem from the protocol; selling is the only exit; expect a discount vs unlocked spot.

## C2: MET

Do not put MET in C1. Unstake exists. `redeemDelay` >= Meteora unbonding (~21d). Mature `claim` still works while paused.

Solana listings wait for a Solana lockbox. Do not fake them on the EVM Adapter.
