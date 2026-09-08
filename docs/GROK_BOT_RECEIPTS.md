# Grok bot — listing harvest notes (after canary)

**Deploy order and copy-paste:** [`GROK_BOT_MAINNET.md`](GROK_BOT_MAINNET.md).
That file is the task list. This table is only harvest/never per ticker.
`BATCH` locks the ticker. Do not use deleted testnet scripts.

| ASSET | BATCH | Harvest | Never |
| --- | --- | --- | --- |
| `hxsquid` / `havnt` | 1 | `pokeRewards` `0x9a99b4f0` then `pullYield` QUID/AVNT | inner as poke target; `0xeab52318` |
| `hcbeth` | 2 | 1% of `exchangeRate` surplus | pull more than the skim |
| `hgsoon` / `hswbera` | 2 | 1% of `convertToAssets` surplus | cooldown / 7d NFT queue |
| `hsavax` | 3 | 1% of `getPooledAvaxByShares` | `requestUnlock` |
| `hsethfi` | 3 | none this round (yield in share) | DelayedWithdraw / teller deposit / merkle poke |
| `hstkwausdc` | 3 | 1% rate skim + `RewardsController` `0xbb492bf5` | `cooldown` on StakeToken |
| `hlbtc` | 3 | 1% of AssetRouter `getRate` surplus. Jump >3% **up or down** is not yield | BTC.b / LBTCv / BTCe / Base LBTC / `burn` / `mint(bytes,bytes)` / AssetRouter `deposit` / Bascule |
| `bluai4y` / `horder` | 4 | farm claim / ledger harvest | `setShareExit`; CREATE2 twin |
| `hjitosol` | 5 | 1% of JitoSOL/SOL rate surplus (escrow → harvest ATA). Spec `solana/leaf-jito-rate` | NCN / VRT / stake-pool CPI / Rewarder / `WirePeers` |

`pullYield(inner)` on rate L **is** the 1% skim. On hxSQUID it must revert `CannotPullInner`.
