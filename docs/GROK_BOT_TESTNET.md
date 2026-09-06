# Grok bot — first testnet pass

Do **not** deploy mainnet. Do **not** set `INNER_TOKEN` to live sKAITO / xSQUID / cbETH / BLUAI.

Follow `docs/testnet-deploy.md`. HyperEVM testnet DVNs are LayerZero Labs + P2P only. Skip `SetSecurityStack`.

## Order

1. `ASSET=hxsquid` — Base Sepolia → HyperEVM 998. Kind L (`LeafOFTAdapter` + `LeafOFT`).
2. `ASSET=hcbeth` — same path, different ticker.
3. `ASSET=bluai4y` — BSC testnet → 998. Kind C1 (`LeafInboundLockbox` + `LeafClosedOFT`). Dest `send` must revert.

After each source deploy, owner should:

```
setConvertYieldToHype(true)
setHarvester(HARVESTER)     # not OWNER
setConverter(CONVERTER)     # allowlisted pullYield target
```

For hxSQUID only:

```
setRewardsSelector(0x9a99b4f0)
```

## Pass / fail

| Check | hxsquid / hcbeth | bluai4y |
| --- | --- | --- |
| Deposit mints dest ticker | yes | yes |
| Burn dest returns inner on source | yes | **no** — `ExitViaMarketOnly` |
| `pullYield(inner)` reverts | yes (xSQUID / cbETH) | no — C1 may pull surplus BLUAI |
| Reverse LZ into source | n/a | revert `InboundOnly` |

Log every address in the PR. Tiny caps. Separate OWNER / GUARDIAN / HARVESTER.

Testnet `bluai4y` uses a mock inner on BSC testnet and **does not** call `setFarm`. Mainnet (chain 56) owner calls `setFarm(0x94b9865E…5040, stake(uint256,uint256), 4, claimAll())`.


