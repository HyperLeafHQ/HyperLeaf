# Listing order (internal)

Public README shows what users will see. This file is why a ticker is here, parked, or blocked.

One path at a time. Same chain + same Kind can batch after that path is proven.

| Order | Ticker | Kind | Source | Status |
| ----- | ------ | ---- | ------ | ------ |
| 0 | hNEST | Native | HyperEVM | Live, capped |
| 1 | hxSQUID | L | Base | First wrap. claimRewards → QUID → HYPE |
| 2 | hcbETH | L | Base | PoS in the rate |
| later | **hsETHFI** | L | Ethereum | Receipt only. Never 10d DelayedWithdraw |
| later | **hgSOON** | L | **BSC** `0xcC48…` | ERC-4626. Never `cooldownShares` 0x9343d9e1 / `claim` 0x1e83409a. Never 90d lock `0x6601` |
| later | **hAVNT** | L | Base | Wrap **stkAVNT**. Your `0x7aaf51e8`. Never `cooldown()` (live 18h). Slash ≤20% |
| later | **PTSMAX** | C1 | BSC | River Pts → sRIVER_V2 NFT. NFT lockbox |
| later | **hB3** | C1 | Base | stakeFor on 0x18541. Principal to EOA 0x8D06. Need WIN claim tx |
| later | **hORDER** | C1 | OP OFT → Orderly 30213 | `stakeOrder` 0x413aaa60. VALOR on lockbox. Need VALOR redeem tx |
| later | hveAERO | ve-NFT | Base | Needs NFT lockbox |
| later | hsWBERA | L | Berachain | Wait LZ |
| later | hAEVO / hGMX | C1 | ETH / Arb | No transferable receipt |
| later | hJupSOL / hANSEM | L | Solana | Needs Solana lockbox |
| later | hwstETH | L | Ethereum | Own ticker, not mixed with hcbETH |
| later | BLUAI4Y | C1 | BSC | High user risk. unstake 0x2e17de78 |
| last | BONK12M / hMET | C1/C2 | Solana | |
| parked | hSKY | C1 | Ethereum | Stake-only strips LockStake borrow. Min 1.44M SKY / 30k USDS |
| hold | hstkAAVE | | Ethereum | Safety Module → Umbrella |
| parked | hLIT | | Lighter L2 | Stake is on Lighter zk-rollup. LZ has no endpoint. LLP is not the issue |
| watch | hSEED | C1 | Arbitrum | Stake still Arb; cbBTC rewards on Base. No Base stake until UI proves it |
| blocked | hKAITO / hVIRTUALMAX | | Base | Extra-chain claims until CREATE2 holder |

Out of scope: RAM/HYBR official LSTs, ENA/sENA, Hyperliquid-native HYPE LSTs.

## Phases

**A** — testnet hxSQUID then hcbETH (`GROK_BOT_TESTNET.md`), then mock BLUAI4Y so C1 is not confused with L.
**B** — mainnet hxSQUID, tiny cap.
**C** — hcbETH.
**D** — skip hSKY.
**E** — veAERO / remaining Ethereum (not SKY).
**F** — sWBERA / AEVO / GMX / JupSOL / ANSEM.
**G** — hKAITO / hVIRTUALMAX after omnichain holder.
**H** — NestVault v2 optional (PR #5). Do not migrate live test NEST until v2 is tested.
**Later** — HyperEVM strategy vaults are **not** Leaf listings. Revisit only after hxSQUID/hcbETH are used as collateral.

Catalog: [`listings/catalog.json`](../listings/catalog.json) · kinds: [`wrap-kinds.md`](wrap-kinds.md).
