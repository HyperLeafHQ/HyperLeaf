# Grok bot — listing harvest notes (after canary)

**Deploy order and copy-paste:** [`GROK_BOT_MAINNET.md`](GROK_BOT_MAINNET.md).
That file is the task list. This table is only harvest/never per ticker.
`BATCH` locks the ticker. Do not use deleted testnet scripts.

| ASSET | BATCH | Harvest | Never |
| --- | --- | --- | --- |
| `hxsquid` / `havnt` | 1 | `pokeRewards` `0x9a99b4f0` then `pullYield` QUID/AVNT | inner as poke target; `0xeab52318` |
| `hcbeth` | 2 | 1% of `exchangeRate` surplus | pull more than the skim |
| `hgsoon` / `hsibera` | 2 | 1% of `convertToAssets` surplus | cooldown / 7d NFT queue / sWBERA / iBERA |
| `hslisbnb` | 2 | 1% of StakeManager `convertSnBnbToBnb` surplus. Jump 300 bps. `rewardsTarget` = Lista StakeManager, **not** the token | native BNB `deposit()` / Lista 7d `requestWithdraw` / `claimWithdraw` / `instantWithdraw`. Never `convertToAssets` on slisBNB |
| `hsavax` | 3 | 1% of `getPooledAvaxByShares` | `requestUnlock` |
| `hstkwausdc` | 3 | 1% rate skim + `RewardsController` `0xbb492bf5` | `cooldown` on StakeToken |
| `hlbtc` | 3 | 1% of AssetRouter `getRate` surplus. Jump >3% **up or down** is not yield | BTC.b / LBTCv / BTCe / Base LBTC / `burn` / `mint(bytes,bytes)` / AssetRouter `deposit` / Bascule |
| `hsteakusdg` | later — **not a BATCH** | none. Yield stays in the share. `pullInner` false | USDG / steakUSDC / 4626 `deposit`/`mint`/`withdraw`/`redeem` / Morpho Blue market. Never `RateKind.ConvertToAssets` (6-dec asset) |
| `hdai` | later — **not a BATCH** | none. Yield stays in the share. `pullInner` false | DAI / Maker sDAI / Trust Wallet wrapper / 4626 / Morpho Blue. Cap 100_000e18 shares. Do not advertise APY |
| `hkaito` / `hvirtualmax` | later — **not a BATCH** | `pokeMerkleClaim` `0x2e7ba6ef` then `pullYield` / holder `sweep`. Twin never `openBridge` | raw KAITO / official 7d unstake / VIRTUAL redeem / `rewardsSelector=0x2e7ba6ef` |
| `bluai4y` / `horder` | 4 | farm claim / ledger harvest | `setShareExit`; CREATE2 twin for ORDER |
| `hjitosol` | 5 | 1% of JitoSOL/SOL rate surplus (escrow → harvest ATA). Spec `solana/leaf-jito-rate` | NCN / VRT / stake-pool CPI / Rewarder / `WirePeers` |

`pullYield(inner)` on rate L **is** the 1% skim. On hxSQUID it must revert `CannotPullInner`.
