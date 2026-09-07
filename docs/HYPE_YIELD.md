# Yield: claim on source, convert off-chain, pay HYPE

Two steps. Do not merge them into one user button.

## 1. Permissionless `harvestRewards()` (source chain)

Anyone pays gas. Call `LeafCallRewardSource.harvest(lockbox)` or the farm’s own claim if it already pays the lockbox. No swap. No inner movement.

HyperEVM mempool: **8 pending txs per sender**. Harvest / `poke` / `notify` are permissionless so a single keeper key is not required. If you do run a bot: wallet pool, and **gas < 3M** (else the tx sits in the 1-minute big block). Weekly is enough.

- Settled BLUAI / QUID / airdrops land **in the lockbox**.
- No swap. No inner receipt movement.
- Pass a `LeafCallRewardSource` (owner-set protocol claim payload) or the farm if it already implements `harvest(lockbox)`.

## 2. Weekly (or size-gated) keeper — not 24/7

Harvester-only `pullYield`. Then swap + bridge + `LeafHypeRewarder.notify`.

| Listing | Unlock | What you may pull | What you must not pull |
| --- | --- | --- | --- |
| **hKAITO** | L, return sKAITO | Eco airdrop ERC-20s (allowlisted) | **sKAITO** — PoS is already in the ERC-4626 rate |
| **hxSQUID** | L, return xSQUID | **QUID** | **xSQUID** |
| **hcbETH** | L, shares of remaining cbETH | **Rate surplus only** (`exchangeRate` × dRate / rate) | Principal. Coinbase unwrap. More than surplus |
| **BLUAI4Y** | C1, market only | Extra **BLUAI** (`pullInnerEnabled = true`, surplus only) | Principal (`totalLocked`) |
| **hVIRTUALMAX** | C1 | Agent airdrops | Staked VIRTUAL (Auto Max-lock) |

`pullInner` is **hardcoded by kind**: L / C2 adapters revert `CannotPullInner` unless a **rate feed** is set. Then only the rate-implied surplus may leave (`setRateKind(ExchangeRate)` for cbETH, `ConvertToAssets` for 4626). C1 lockbox may pull extra inner (BLUAI). Surplus = `balance - totalLocked` (C1) or `free * (rate - lastRate) / rate` (rate L).

1% protocol / 99% holders happens on HyperEVM at `notify`, not on the source swap. Rate surplus is sold to WHYPE first; `notify` then splits. Redeem after harvest is pro-rata remaining inner, not 1 token = 1 token.

## Rate-bearing (hcbETH) — where the 1% comes from

cbETH does not mint extra tokens. ETH PoS lives in Coinbase `exchangeRate()`. There is no airdrop to claim. The only honest take of depositor yield is to sell the **rate-implied surplus**:

```
surplus = free − free × lastRate / rate
```

Example: deposit 100 cbETH at rate 1.00. Later rate 1.10.

| | cbETH | ETH value |
| --- | ---: | ---: |
| Locked | 100 | 110 |
| Surplus pulled (`100 − 100/1.10`) | 9.0909 | 10 (the yield) |
| Stays in the box | 90.9091 | 100 (principal) |

Converter sells 9.0909 cbETH → WHYPE. `LeafHypeRewarder.notify`:

- protocol **1%** of that WHYPE
- holders **99%**, claimable, does not burn the Leaf

Redeem 100 hcbETH → **90.9091 cbETH** (still ~100 ETH) plus the HYPE they claimed. 1 hcbETH ≠ 1 cbETH after harvest. The 1% is of **yield**, never of the deposit.

Slash (`rate < lastRate`): watermark drops, pull 0. Later deposits mint at NAV (`_sharesForAssets`).

xSQUID is the other class: QUID is a different ERC-20, so redeem stays 1 xSQUID = 1 xSQUID. Same 99/1 after the QUID is sold.

## Routes (keeper)

| Source | Harvest into | Bridge |
| --- | --- | --- |
| Base (QUID, KAITO airdrops) | Wormhole NTT HYPE `0x15D0…f68d` | Portal / Relay → WHYPE |
| BSC (BLUAI surplus) | USDC — never fake BSC HYPE | **Relay** dest=WHYPE; deBridge USDC fallback |
| Solana | Wormhole HYPE `98sMhv…Mh5g` | Portal |

Not cbHYPE. Not BSC ticker-HYPE.

Run when surplus clears Relay min and gas < ~1% of the batch. Weekly is enough. Cron / Gelato, not a mint relayer.

## Deploy

```
# after wrap + rewarder
cast send $ADAPTER "setConvertYieldToHype(bool)" true
cast send $ADAPTER "setHarvester(address)" $KEEPER
cast send $ADAPTER "setConverter(address)" $CONVERTER
# poke: LeafCallRewardSource.harvest(lockbox) — anyone
# pullYield only to $CONVERTER. notify reverts if hToken supply is 0.

# poke: harvestRewards(LEAF_CALL_SOURCE) — anyone
# BLUAI4Y C1 pullYield(BLUAI) is extra inner only
```
