# Listing order (internal)

Public README shows what users will see. This file is why a ticker is here, parked, or blocked.

Cross-chain go-live is **mainnet**. Testnet cannot run Labs+Horizen+Canary or the send/receive confirmation split. One path at a time. Same framework + proven chain can batch.

| Order | Ticker | Kind | Source | Status |
| ----- | ------ | ---- | ------ | ------ |
| 0 | **hCANARY** | L | Base | Toy `LEAFTEST`. Real ULN. Close after redeem. Do not reuse |
| 0 | hNEST | Native | HyperEVM | Live, capped. C1-style product: no UI redeem, secondary market exit. Keep existing vault |
| **1** | hxSQUID | L | Base | **Live v3** SOURCE `0x13E3…0d25` / OFT `0x78B6…4DFc`. Cap 50. Owner pending FINAL |
| **1** | **hAVNT** | L | Base | **Live** `0x571C…aa98` both chains. Cap 50. Owner pending FINAL |
| **2** | **hgSOON** | L | BSC | `convertToAssets` 1% skim. Never 90d cooldown |
| **2b** | **hslisBNB** | L | BSC | Lista slisBNB only. Same BSC path as hgSOON. Never native BNB. Never Lista 7d unstake |
| **2** | **hsWBERA** | L | Berachain 80094 | Same skim. Never 7d NFT queue |
| **3** | **hsAVAX** | L | Avalanche | BENQI. `getPooledAvaxByShares`. Never `requestUnlock` |
| **3** | **hLBTC** | L | Ethereum | LBTC only. 8-dec. Router getRate. 3% jump breaker. Not BTC.b |
| **3** | **hstkwaUSDC** | L | Ethereum | stkwaEthUSDC.v1. Rate + RewardsController. Never cooldown / v2 migrate |
| **4** | BLUAI4Y | C1 | BSC | No protocol redeem. Claim Board |
| **4** | **hORDER** | C1 | **Arbitrum only** | `LeafInboundLockbox` + Orderly proxy. No CREATE2 twin |
| later | **hsPOL** | L | Ethereum | Polygon Labs sPOL. Rate = controller.convertSPOLtoPOL. Never POL / child. `feat/hspol`. Not a BATCH yet |
| later | **hB3** | C1 | Base | stake → queue WIN (0x58016b6a) → 24h → claim B3 (0x087ce4a0). Claim poke still off until recipient=lockbox. `feat/hb3` |
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
| last | hwstETH / hcbETH | L | Ethereum / Base | ETH LST last. Official weETH already on HyperEVM. Do not list weETH/ezETH. hLBTC/hstkwaUSDC stay |
| last | BONK12M / hMET | C1/C2 | Solana | After the LST lockbox exists |
| parked | hSKY | C1 | Ethereum | Stake-only strips LockStake borrow. Min 1.44M SKY / 30k USDS |
| parked | hGMX | C1 | Arbitrum | Stake yield frozen until $90. GLP V1 retired 2025-07-16 |
| parked | **hUNCX** | — | Ethereum | Stake rewards + buybacks paused 2026-08-21. Lockers still earn; not paid to stakers |
| parked | **hSNX** | — | Ethereum | 420 Pool closed Jun 2026. Phase 4 staking deferred. Spot only |
| later | **hstDYDX** | L | Cosmos/Stride | Wrap **stDYDX**, never ethDYDX. Needs IBC lockbox like JupSOL |
| hold | hstkAAVE | | Ethereum | Legacy SM. Umbrella path is **hstkwaUSDC**, not this ticker |
| parked | hLIT | | Lighter L2 | Stake is on Lighter zk-rollup. LZ has no endpoint. LLP is not the issue |
| blocked | **BNBx** | | BSC | Stader sunset 2026 |
| watch | hSEED | C1 | Arbitrum | Stake still Arb; cbBTC rewards on Base. No Base stake until UI proves it |
| blocked | hKAITO / hVIRTUALMAX | | Base | Extra-chain claims until CREATE2 holder |

Out of scope: RAM/HYBR official LSTs, ENA/sENA, Hyperliquid-native HYPE LSTs.

## Phases

**0** — mainnet canary (`hcanary` / `LEAFTEST` on Base 8453 ↔ HyperEVM 999). Real `SetSecurityStack`. Tiny cap. Close after redeem. `GROK_BOT_MAINNET.md`.
**1** — hxSQUID then hAVNT. Same Base path the canary just proved.
**2** — rate L: **hgSOON (BSC) then hsWBERA (Bera)**. 1% skim. New LZ eids 30102 / 30362. **ETH LST family last** (weETH already on HyperEVM; Base cbETH has no `exchangeRate`). **hslisBNB only after hgSOON**.
**3** — hsAVAX (Avax) + hstkwaUSDC + hLBTC (Ethereum). Not ETH. hsETHFI gated (`productionEvm=false`).
**4** — C1: BLUAI4Y then hORDER. Leaf Market after the first C1 lists. No CREATE2 twin.
**A′** — do **not** seed a HyperEVM AMM. C1 / queued listings get a peer **claim board** (`docs/CLAIM_MARKET.md`). Protocol never bids.
**E** — veAERO NFT lockbox (`LeafNftLockbox`). Permanent NORMAL only. Not a grok-bot batch until a canary of this box exists.
**G** — hKAITO / hVIRTUALMAX after omnichain holder.
**H** — NestVault v2 optional (PR #5). Do not migrate live test NEST until v2 is tested.
**5** — hJitoSOL. Grok bot: Docker `anchor build -v` → deploy `.so` → Store PDA → HyperEVM dest OFT. Task list: `GROK_BOT_MAINNET.md` §5. NCN out.
**Later** — HyperEVM strategy vaults are **not** Leaf listings. Revisit only after hxSQUID/hAVNT are used as collateral. ETH LSTs (wstETH / weETH / ezETH / cbETH) after that.

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

