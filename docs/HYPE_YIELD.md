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
| **hcbETH** | L, return cbETH | **nothing** | **cbETH**. Only ETH PoS, already in the cbETH/ETH rate. No side airdrops. Do not `notify` WHYPE. Do not show 领取 HYPE. |
| **BLUAI4Y** | C1, market only | Extra **BLUAI** (`pullInnerEnabled = true`, surplus only) | Principal (`totalLocked`) |
| **hVIRTUALMAX** | C1 | Agent airdrops | Staked VIRTUAL (Auto Max-lock) |

`pullInner` is **hardcoded by kind**: L / C2 adapters revert `CannotPullInner`. C1 lockbox may pull extra inner (BLUAI). Surplus = `balance - totalLocked`.

1% protocol / 99% holders happens on HyperEVM at `notify`, not on the source swap.

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
