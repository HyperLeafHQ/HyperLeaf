# Yield: claim on source, convert off-chain, pay HYPE

Two steps. Do not merge them into one user button.

## 1. Permissionless `harvestRewards()` (source chain)

Anyone pays gas. L: `pokeRewards` on the adapter (hxSQUID `claimRewards(this, max)`). C1: `pokeRewards` on the farm (`farmClaimSel`). Then anyone `pullYield(..., converter)` — no DEX, destination is the converter only. No generic `pokeClaim`. No swap. No inner movement.

HyperEVM mempool: **8 pending txs per sender**. `poke` / `pullYield` are permissionless so a single keeper key is not required for harvest. `execute` / `notify` still need the keeper. If you do run a bot: wallet pool, and **gas < 3M** (else the tx sits in the 1-minute big block). Weekly is enough.

- Settled BLUAI / QUID / airdrops land **in the lockbox**.
- No swap. No inner receipt movement.
- Owner sets `setRewardsSelector` (L) or `setFarm` claim selector (C1). Do not deploy a second harvest contract.

## 2. Weekly (or size-gated) keeper — not 24/7

Harvester-only `execute` / `notify` on `LeafYieldConverter`. `pullYield` is already done. Swap + bridge + `notify` stay keyed because (1) bridge calldata has no price floor, (2) `notify(id)` chooses which listing gets the WHYPE.

Converter rules:

1. Inventory sits in the converter contract.
2. Each hop is an allowlisted `route` (Aerodrome / 1inch / Relay / Portal / **deBridge** / **Mayan** / …) with `minOut` **and** `deadline`. `minOut` cannot be 1 wei: it must be ≥ `requiredMinOut` = max(owner `minPriceX18`, last fill × (1 − maxSlippageBps)). Default slip 3%. That is the sandwich floor. Prefer Cow / Mayan / deBridge RFQ over a public AMM mempool.
3. `notify(id, amount, minAmount)` cannot credit more WHYPE than the contract holds, and cannot go below the keeper quote.
4. If no route fills: `converter.halt([lockbox])` → `lockbox.haltConvert()` → further `pullYield` reverts `ConvertHalted`. Wrap/redeem stay live. Owner turns convert back on after a route works.
5. Unsold tokens `returnToLockbox` only. Never to an EOA.

Owner must `setMinPrice(tokenIn, tokenOut, outPerIn×1e18)` before the first swap of that pair. A real dump: owner lowers the floor. Keeper must not use a public Uni v2 swap as the first hop.


Same converter bytecode on source (swap/bridge) and HyperEVM (`setRewarder` + `notify`).


| Listing | Unlock | What you may pull | What you must not pull |
| --- | --- | --- | --- |
| **hKAITO** | L, return sKAITO | Eco airdrop ERC-20s (allowlisted) | **sKAITO** — PoS is already in the ERC-4626 rate |
| **hxSQUID** | L, return xSQUID | **QUID** | **xSQUID** |
| **hcbETH** | L, shares of remaining cbETH | **Rate surplus only** (`exchangeRate` × dRate / rate) | Principal. Coinbase unwrap. More than surplus |
| **hsAVAX** | L, shares of remaining sAVAX | **Rate surplus only** (`getPooledAvaxByShares`) | Principal. BENQI `requestUnlock`. More than surplus |
| **hgSOON** | L, remaining gSOON | **Rate surplus 1%** (`convertToAssets`) | Principal. SOON. `deposit` / `cooldownShares` / 90d `lock`. More than the 1% |
| **BLUAI4Y** | C1, market only | Extra **BLUAI** (`pullInnerEnabled = true`, surplus only) | Principal (`totalLocked`) |
| **hVIRTUALMAX** | C1 | Agent airdrops | Staked VIRTUAL (Auto Max-lock) |

`pullInner` is **hardcoded by kind**: L / C2 adapters revert `CannotPullInner` unless a **rate feed** is set. Then only the rate-implied surplus may leave (`setRateKind(ExchangeRate)` for cbETH; `GetPooledAvaxByShares` for sAVAX; `ConvertToAssets` only if that listing's SOLVENCY row opts in). C1 lockbox may pull extra inner (BLUAI). Surplus = `balance - totalLocked` (C1) or `(lastAccounted * (rate - lastRate)) / rate` (rate L, floor, principal only). Donations are not surplus.

1% protocol / 99% holders at `notify` is **side-token yield only** (QUID, airdrops). Rate-bearing L (`retainRateYield`): 1% of surplus to converter, 99% stays in the receipt. Wrap/redeem do **not** transfer to the converter. `pullYield` is the only inner outflow for yield.


## Rate-bearing (hcbETH) — Lido-style, 1% skim

cbETH does not mint extra tokens. ETH PoS lives in Coinbase `exchangeRate()`.
HyperLeaf does **not** sell that yield to WHYPE for holders. `retainRateYield`:

```
surplus = (lastAccounted × (rate − lastRate)) / rate     // floor
fee     = surplus × 1%                                   // protocol only
99% of surplus stays in the lockbox
```

`lastAccounted` is pulled principal, not `balanceOf`. A donation into the lockbox does not raise it.

Example: deposit 100 cbETH at rate 1.00. Later rate 1.10.


| | cbETH | ETH value |
| --- | ---: | ---: |
| Locked | 100 | 110 |
| Protocol skim (1% of 9.0909) | 0.0909 | 0.10 |
| Stays in the box | 99.9091 | 109.90 |

Converter sells **0.0909 cbETH** → WHYPE → **protocol fee recipient**. Holders do **not** `notify` / claim. Redeem 100 hcbETH → **99.9091 cbETH** (still ~109.9 ETH). LP of hcbETH keeps that ETH value. The 1% is of **yield**, never of the deposit.

Slash (`rate < lastRate`): watermark drops, pull 0.

xSQUID is the other class: QUID is a different ERC-20, so redeem stays 1 xSQUID = 1 xSQUID. QUID → WHYPE → `notify` 99/1. That Rewarder path **does** allocate by address; see `HYPE_COMPOSABILITY.md`. `minNotify` still applies there.

`notify` reverts `DustNotify` when the batch cannot bump `accHypePerShare`. Keeper: read `minNotify(listingId)` and wait until harvested WHYPE ≥ that. Do not retry dust.

## Routes (keeper)

| Source | Harvest into | Bridge |
| --- | --- | --- |
| Base (QUID, KAITO airdrops) | Wormhole NTT HYPE `0x15D0…f68d` | Portal / Relay → WHYPE. **Fallback: deBridge, Mayan** (allowlist the router, same `execute`) |
| BSC (BLUAI surplus) | USDC — never fake BSC HYPE | **Relay** dest=WHYPE; deBridge / Mayan USDC fallback |
| Solana | Wormhole HYPE `98sMhv…Mh5g` | Portal; Mayan fallback |

Not cbHYPE. Not BSC ticker-HYPE.

Run when surplus clears Relay min and gas < ~1% of the batch. Weekly is enough. Cron / Gelato, not a mint relayer.

## Deploy

```
# LeafYieldConverter (source + HyperEVM). Never setConverter to an EOA.
OWNER=$OWNER KEEPER=$KEEPER GUARDIAN=$GUARDIAN \
forge script script/lz/DeployYieldConverter.s.sol:DeployYieldConverter \
  --rpc-url base_sepolia --broadcast --private-key $PRIVATE_KEY
# HyperEVM: same + REWARDER=... (script calls setRewarder)

cast send $ADAPTER "setConvertYieldToHype(bool)" true
cast send $ADAPTER "setHarvester(address)" $KEEPER
cast send $ADAPTER "setConverter(address)" $CONVERTER
# owner: converter.setLockbox(adapter, true); setToken(QUID); setOutput(NTT HYPE / USDC / WHYPE)
#        setRoute(aerodrome); setRoute(debridge); setRoute(mayan); setRoute(relay)
# hop:   converter.execute(tokenIn, amt, tokenOut, minOut, route, data, deadline)
#        minOut >= converter.requiredMinOut(tokenIn, tokenOut, amt)
# fail:  converter.halt([adapter])  then try the next route after unhalt
# home:  converter.returnToLockbox(adapter, token, amt)
```

