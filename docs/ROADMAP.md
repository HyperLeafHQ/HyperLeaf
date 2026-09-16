# Listing order (internal)

Public README shows what users will see. This file is why a ticker is here, parked, or blocked.

Cross-chain go-live is **mainnet**. Testnet cannot run Labs+Horizen+Canary or the send/receive confirmation split. One path at a time. Same framework + proven chain can batch.

| Order | Ticker | Kind | Source | Status |
| ----- | ------ | ---- | ------ | ------ |
| 0 | **hCANARY** | L | Base | Toy `LEAFTEST`. Real ULN. Close after redeem. Do not reuse |
| 0 | hNEST | Native | HyperEVM | **LIVE** occupancy C1. Vault `0xaE7C…755c` / hNEST `0x6dC4…122F`. Leaf Market `0x6f29…CB34`. No UI redeem |
| **1** | **hQUID** | L | Base | **LIVE uncapped.** SOURCE `0xe406bBADf8802eB26813fb1447f5E2BCAEDB8F25` / OFT `0x3d2768A86EF75382cd0B83BeC7C7B470CAD840C1`. Dead 50-cap `0x13E3…` / `0x78B6…` |
| **1** | **hAVNT** | L | Base | **LIVE uncapped.** SOURCE `0xEfE86555554cfeba484871571550E4b21B2Cd141` / OFT `0x801688aDb52452658Ea165dd554FC0102E36a1b3`. Dead `0x571C…` / `0xAA70…` / `0x9a75…` |
| parked | hcbETH | L | Base | No `exchangeRate` on Base cbETH. Not BATCH 2 |
| **2** | **hgSOON** | L | BSC | **LIVE.** SOURCE `0x90A08243b0e3Fe1F00E51c0b5A22336600cfA016` / OFT `0x36c405698776fc28DEceDD25B3f081dB851F4c5b`. `convertToAssets` 1% skim. Jump 3%. Never 90d cooldown |
| **2b** | **hslisBNB** | L | BSC | Pins landing. Lista `convertSnBnbToBnb` on StakeManager. Same BSC path as live hgSOON. Never native BNB / 7d unstake. Not live |
| **2** | **hsWBERA** | L | Berachain 80094 | Same skim. Never 7d NFT queue. Not live |
| **3** | **hsAVAX** | L | Avalanche | BENQI. `getPooledAvaxByShares`. Never `requestUnlock` |
| **3** | **hLBTC** | L | Ethereum | LBTC only. 8-dec. Router getRate. 3% jump breaker. Not BTC.b |
| **3** | **hstkwaUSDC** | L | Ethereum | stkwaEthUSDC.v1. Rate + RewardsController. Never cooldown / v2 migrate |
| **4** | **BLUAI4Y** | C1 | BSC | **LIVE.** SOURCE `0x4360794c42BB437B156F20b33325dAC84B7e6d8a` / OFT `0x8F25a342b93f623A07e7dF8b691a729A6e39C439`. Escrow `0x367FB8…` / Fill `0xE3E4B1…`. Dead 100-cap in catalog `dead[]`. Do not `setDepositCap(0)` on live SOURCE |
| **4** | **hORDER** | C1 | **Arbitrum only** | Queued. Cookbook #69. Wait for human `GO`. Inner Arb ORDER OFT `0x4E20…97B8`. Never ETH `0xABD4…`. Never BLUAI escrow |
| pre | **VAR** | Pre | HyperEVM factory | **LIVE** claims in USDM. Factory `0x22684F6e…`. Settle hVAR after TGE |
| pre | **Predict** | Pre | HyperEVM factory | **LIVE** claims in USDM. Same factory. Settle hPREDICT after TGE |
| pre | **Nado** | Pre | HyperEVM factory | Opening. Same factory n=3. `createMarket("Nado points","Nado",sUSDM)`. Settle **hINK** after official INK. Not live |
| later | **PTSMAX** | C1 | BSC | River Pts → sRIVER_V2 NFT. NFT lockbox |
| later | **hB3** | C1 | Base | stakeFor on 0x18541. Principal to EOA 0x8D06. Need WIN claim tx |
| later | hveAERO | ve-NFT | Base | `LeafNftLockbox` exists. Permanent NORMAL only. Not a BATCH |
| later | **hveUP** | ve-NFT | Robinhood 4663 | up. DEX. Wrap **veUP NFT**, never liquid UP. Same NFT lockbox as veAERO. LZ eid 30416 |
| later | **hsteakUSDC** | L | Base Morpho | steakUSDC `0xBEEF010f…8183`. Same L family as hsteakUSDG |
| later | **hDAI** | L | Ethereum Morpho | Gauntlet DAI Core V1 `0x500331c9…74a5`. Wrap **vault shares**, never DAI, never Blue market. **Cap 100k DAI** (exit liq ~195k). Pilot, not unlimited. Do not advertise 6.29% |
| later | **hUSDT** | L | Bitway | Core Alpha share **BTWUSDT** `0x73af543D…3A1` / vault `0xb82E32…B63`. Never raw USDT. Value-accruing, not a 1:1 USDT wrap. Verify ABI + chain + LZ before any BATCH |
| later | **hsteakUSDG** | L | Robinhood Morpho | steakUSDG `0xBeEf…09dd`. Never deposit/redeem USDG |
| later | **asBNB** | L | BSC | Aster extra rewards on top of LST — later, not first |
| watch | **hUSD1** | L | BSC HertzFlow | HLV Genesis `0xeeA83A77…da9c6`. Wrap **HLV receipt**, never raw USD1. Perp LP NAV can drop; withdraw can stall. Campaign WLFI is **not** backing. SELECTED pending share-token ID |
| watch | **hbwBTW** | L | Bitway | bwBTW only, never raw BTW. ~5% + volatile. Low priority |
| watch | **ankrBNB** | L | BSC | Rate-compatible; liquidity << slisBNB |
| watch | **htsTON** | L | TON | Tonstakers **tsTON** only, never raw GRAM. Luna #02. sGRAM/hGRAM secondary. BLOCK until TON LZ + receipt mint verified |
| watch | **hsTRX** | L | TRON | JustLend sTRX `TU3kjFuh…SLQ5` only. Instant hsTRX vs sTRX, not raw TRX. 14d source unbond stays on JustLend. **No LZ TRON mainnet ULN yet** |
| watch | **hLINK** | C2 | Ethereum | Chainlink Staking v0.2. Community pool **full**, per-address **15k LINK**, 28d+7d exit. Research only — not an open vault |
| watch | **hliSLVR** | L | Robinhood | Wrap **liSLVR only**. Never taxed SLVR. Lottery rake. Confirm tax-free share |
| watch | **hTWO** | C2 | Robinhood | Twofold. No receipt; 1h/7d stake vaults. Do not wrap TWO or vTWO |
| watch | **hSB** | ve-NFT | Robinhood | StonkBrokers. Wrap **activated NFT**, never $STONKBROKER. TBA + geo. Skip until NFT lockbox |
| **5** | **hJitoSOL** | L | Solana | Rate LST. Not NCN VRT |
| watch | **hfragSOL** / **hkySOL** / **hezSOL** | L/C2 | Solana | Jito Vault **VRT**. Receipt exists. Slash + unstake queue. After hJitoSOL, not instead of it |
| later | **hANSEM** | L? | Solana | Watch. Memecoin + launchpad airdrops, not an LST receipt |
| later | hwstETH | L | Ethereum | Own ticker, not mixed with hcbETH |
| last | BONK12M / hMET | C1/C2 | Solana | After the LST lockbox exists |
| parked | hSKY | C1 | Ethereum | Stake-only strips LockStake borrow. Min 1.44M SKY / 30k USDS |
| parked | hGMX | C1 | Arbitrum | Stake yield frozen until $90. GLP V1 retired 2025-07-16 |
| parked | **hUNCX** | — | Ethereum | Stake rewards + buybacks paused 2026-08-21. Lockers still earn; not paid to stakers |
| parked | **hSNX** | — | Ethereum | 420 Pool closed Jun 2026. Phase 4 staking deferred. Spot only |
| later | **hstDYDX** | L | Cosmos/Stride | Wrap **stDYDX**, never ethDYDX. Needs IBC lockbox like JupSOL |
| hold | hstkAAVE | | Ethereum | Legacy SM. Umbrella path is **hstkwaUSDC**, not this ticker |
| parked | hLIT | | Lighter L2 | Stake is on Lighter zk-rollup. LZ has no endpoint. LLP is not the issue |
| skip | **TAO** | — | — | Tensorplex Stake & Bridge sunset. No EVM LST. #48 closed. Do not wrap stTAO / tTAO / raw TAO |
| blocked | **BNBx** | | BSC | Stader sunset 2026 |
| watch | hSEED | C1 | Arbitrum | Stake still Arb; cbBTC rewards on Base. No Base stake until UI proves it |
| blocked | hKAITO / hVIRTUALMAX | | Base | Extra-chain claims until CREATE2 holder |

Out of scope: RAM/HYBR official LSTs, ENA/sENA, Hyperliquid-native HYPE LSTs.

## Phases

**0** — mainnet canary (`hcanary` / `LEAFTEST` on Base 8453 ↔ HyperEVM 999). **Done.** Close after redeem. Do not reuse.
**1** — hQUID then hAVNT. **LIVE uncapped.** Same Base path the canary proved.
**2** — rate L: **hgSOON LIVE.** **hslisBNB** Lista pins (`convertSnBnbToBnb`, jump 300, cap 0) — not live. **hsWBERA** catalog already on main — COMING frontend, not live. **hcbETH out** (Base token has no `exchangeRate`).
**3** — hsAVAX (Avax) + hstkwaUSDC + hLBTC (Ethereum). hsETHFI gated (`productionEvm=false`).
**4** — C1: **BLUAI4Y LIVE.** hORDER queued (#69). Leaf Market already live for BLUAI. No CREATE2 twin. New escrow for hORDER — never `0x367FB8`.
**Pre** — VAR + Predict **LIVE** USDM claims on factory `0x22684F6e…`. **Nado** next (`createMarket` n=3, queued). Settlement Leafs after TGE: hVAR / hPREDICT / **hINK** (Ink 57073, inner 0 until official INK).
**A′** — do **not** seed a HyperEVM AMM. C1 / queued listings get a peer **claim board** (`docs/CLAIM_MARKET.md`). Protocol never bids.
**E** — veAERO NFT lockbox (`LeafNftLockbox`). Permanent NORMAL only. Not a grok-bot batch until a canary of this box exists.
**G** — hKAITO / hVIRTUALMAX after omnichain holder.
**H** — NestVault v2 optional (PR #5). Do not migrate live test NEST until v2 is tested.
**5** — hJitoSOL. Grok bot: Docker `anchor build -v` → deploy `.so` → Store PDA → HyperEVM dest OFT. Task list: `GROK_BOT_MAINNET.md` §5. NCN out.
**Later** — HyperEVM strategy vaults are **not** Leaf listings. Revisit only after hxSQUID/hcbETH are used as collateral.

## Solana (batch 5, after EVM 0–4)

Spec crate is in-repo (`solana/leaf-jito-rate`). Mainnet `.so` is Grok bot + Docker + LZ OApp template (`GROK_BOT_SOLANA.md`). `LeafOFTAdapter` is EVM-only. Path is LayerZero eid 30168, not Wormhole. Confirmations 32. Trio Labs + Horizen + Canary. Never Nethermind.

Do **not** mock Solana inners on Base.

| Candidate | Kind | Why / why not |
| --- | --- | --- |
| **jitoSOL** | L rate | **This listing.** Stake-pool rate only. No NCN restake |
| **jupSOL** | later | Same math, after hJitoSOL has live locks. Subsidy APY |
| **mSOL** / **INF** | later | Same math. After jitoSOL |
| **bnSOL** | skip | Binance-issued |
| **hANSEM** | watch | Not an LST |
| **BONK12M** / **hMET** | last | After the JitoSOL program exists |

Harvest on Solana rate LSTs is the cbETH skim (`SOL per share` ↑), not a side token. That skim has to run in the Solana program or an EVM view of a rate oracle — design that with the lockbox, do not pretend `pokeRewards` exists on SPL.

Catalog: [`listings/catalog.json`](../listings/catalog.json) · kinds: [`wrap-kinds.md`](wrap-kinds.md). Comment dump index: [`COMMENT_INDEX.md`](COMMENT_INDEX.md).

