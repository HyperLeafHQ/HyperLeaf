# hRLUSD — later (2026-09-11)

Wrap **senRLUSDv2** only. Never RLUSD. Never Morpho Blue. Never other Sentora vaults.

Official Sentora Morpho RLUSD Main V2 on Ethereum (RPC 2026-09-11):

- Vault `0x6dC58a0FdfC8D694e571DC59B9A52EEEa780E6bf`
- `symbol=senRLUSDv2` · `name=Sentora RLUSD Main` · 18 dec
- `asset()` = Ripple RLUSD `0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD`
- `convertToAssets(1e18)` = 1.011491770467172806
- `totalAssets` ≈ 353.7M RLUSD · `totalSupply` ≈ 349.7M shares
- HyperEVM empty
- [Sentora](https://vaults.sentora.com/vault/1/0x6dc58a0fdfc8d694e571dc59b9a52eeea780e6bf)

Lockbox: `RateKind.ConvertToAssets` + `retainRateYield` + `maxRateJumpBps=300`. Configure checks live `asset()==RLUSD`. Never pin impl. Never `deposit`/`mint`/`withdraw`/`redeem` on the vault. User unwraps **senRLUSDv2** and exits on Morpho.

Do **not** advertise APY. One vault = one listing.

`productionEvm=false`. `NotThisBatch`.
