# Listing order (internal)

Public README shows what users will see. This file is why a ticker is here, parked, or blocked.

One path at a time. Same chain + same Kind can batch after that path is proven.

| Order | Ticker | Kind | Source | Status |
| ----- | ------ | ---- | ------ | ------ |
| 0 | hNEST | Native | HyperEVM | Live, capped |
| 1 | hxSQUID | L | Base | First wrap. claimRewards → QUID → HYPE |
| 1b | **hAVNT** | L | Base | Same adapter + `0x9a99b4f0`. Never `0xeab52318` |
| 2 | hcbETH | L | Base | PoS in the rate |
| **next testnet** | **hstkwaUSDC** | L | Ethereum | Wrap **stkwaEthUSDC.v1** `0x6bf1…8Aa6` only. Dual harvest: 4626 rate + RewardsController. Never cooldown / v2 auto-migrate. After current 4-asset round. |
| **next testnet** | **hsAVAX** | L | Avalanche | BENQI sAVAX `0x2b2C…a4bE`. Same 1% rate skim as hcbETH via `getPooledAvaxByShares`. Never `requestUnlock`. |
| **next testnet** | **hsETHFI** | L | Ethereum | Wrap sETHFI `0x86B578…c0161` only. Never ETHFI, never 10d DelayedWithdraw / teller deposit. Yield in share; KING merkle not this poke |
| **next testnet** | **hgSOON** | L | **BSC** `0xcC48…` | cbETH-class 1% skim via `convertToAssets`. Never `cooldownShares` / 90d lock. BSC testnet 97 |
| later | **PTSMAX** | C1 | BSC | River Pts → sRIVER_V2 NFT. NFT lockbox |
| later | **hB3** | C1 | Base | stakeFor on 0x18541. Principal to EOA 0x8D06. Need WIN claim tx |
| later | **hORDER** | C1 | Arb/Base OFT CREATE2 | Address-keyed lockbox in code. esORDER claim +7d |
| later | hveAERO | ve-NFT | Base | Needs NFT lockbox |
| later | **hveUP** | ve-NFT | Robinhood 4663 | up. DEX. Wrap **veUP NFT**, never liquid UP. Same NFT lockbox as veAERO. LZ eid 30416 |
| later | **hsteakUSDC** | L | Base Morpho | steakUSDC `0xBEEF010f…8183`. Same L family as hsteakUSDG |
| later | **hsteakUSDG** | L | Robinhood Morpho | steakUSDG `0xBeEf…09dd`. Never deposit/redeem USDG |
| watch | **hliSLVR** | L | Robinhood | Wrap **liSLVR only**. Never taxed SLVR. Lottery rake. Confirm tax-free share |
| watch | **hTWO** | C2 | Robinhood | Twofold. No receipt; 1h/7d stake vaults. Do not wrap TWO or vTWO |
| watch | **hSB** | ve-NFT | Robinhood | StonkBrokers. Wrap **activated NFT**, never $STONKBROKER. TBA + geo. Skip until NFT lockbox |
| later | **hsWBERA** | L | Berachain | Wrap sWBERA. Never 4626 withdraw/redeem (7d NFT queue) |
| later | hAEVO | C1 | Ethereum | No transferable receipt |
| later | hJupSOL / hANSEM | L | Solana | Needs Solana lockbox |
| later | hwstETH | L | Ethereum | Own ticker, not mixed with hcbETH |
| later | BLUAI4Y | C1 | BSC | High user risk. unstake 0x2e17de78 |
| last | BONK12M / hMET | C1/C2 | Solana | |
| parked | hSKY | C1 | Ethereum | Stake-only strips LockStake borrow. Min 1.44M SKY / 30k USDS |
| parked | hGMX | C1 | Arbitrum | Stake yield frozen until $90. GLP V1 retired 2025-07-16 |
| parked | **hUNCX** | — | Ethereum | Stake rewards + buybacks paused 2026-08-21. Lockers still earn; not paid to stakers |
| parked | **hSNX** | — | Ethereum | 420 Pool closed Jun 2026. Phase 4 staking deferred. Spot only |
| later | **hstDYDX** | L | Cosmos/Stride | Wrap **stDYDX**, never ethDYDX. Needs IBC lockbox like JupSOL |
| hold | hstkAAVE | | Ethereum | Legacy SM. Umbrella path is **hstkwaUSDC**, not this ticker |
| parked | hLIT | | Lighter L2 | Stake is on Lighter zk-rollup. LZ has no endpoint. LLP is not the issue |
| watch | hSEED | C1 | Arbitrum | Stake still Arb; cbBTC rewards on Base. No Base stake until UI proves it |
| blocked | hKAITO / hVIRTUALMAX | | Base | Extra-chain claims until CREATE2 holder |

Out of scope: RAM/HYBR official LSTs, ENA/sENA, Hyperliquid-native HYPE LSTs.

## Phases

**A** — testnet hxSQUID / hAVNT then hcbETH, then mock BLUAI4Y (`GROK_BOT_TESTNET.md`). Do not add assets to `TestnetCatalog` this round.
**A2** — next testnet: **hgSOON** (BSC 97) + **hsAVAX** (Fuji 43113) + **hstkwaUSDC** + **hsETHFI** (Sepolia). `NextTestnetCatalog` / `TestnetListings`. Do not add them to this round's four-id `TestnetCatalog`. hsteakUSDC later — Umbrella already covers USDC.
**A′** — do **not** seed a HyperEVM AMM to fake spot. C1 / queued listings get a peer **claim board** later (`docs/CLAIM_MARKET.md`). Protocol never bids.
**B** — mainnet hxSQUID, tiny cap.
**C** — hcbETH.
**D** — skip hSKY.
**E** — veAERO / remaining Ethereum (not SKY).
**F** — sWBERA / AEVO / JupSOL / ANSEM.
**G** — hKAITO / hVIRTUALMAX after omnichain holder.
**H** — NestVault v2 optional (PR #5). Do not migrate live test NEST until v2 is tested.
**Later** — HyperEVM strategy vaults are **not** Leaf listings. Revisit only after hxSQUID/hcbETH are used as collateral.

Catalog: [`listings/catalog.json`](../listings/catalog.json) · kinds: [`wrap-kinds.md`](wrap-kinds.md).
