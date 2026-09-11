# hDAI — later, capped (2026-09-11)

Wrap **Gauntlet DAI Core V1 shares** only. Never DAI. Never Morpho Blue. Never Smokehouse DAI.

Official MetaMorpho vault on Ethereum (RPC 2026-09-11):

- Vault `0x500331c9fF24D9d11aee6B07734Aa72343EA74a5`
- `symbol=gtDAIcore` · `name=Gauntlet DAI Core` · 18 dec
- `asset()` = DAI `0x6B175474E89094C44Da98b954EedeAC495271d0F`
- `MORPHO()` = Blue `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb`
- `convertToAssets(1e18)` = 1.176980352995575623
- `totalAssets` ≈ 2.135M DAI · `totalSupply` ≈ 1.814M shares
- `fee` 10% · `timelock` 3d
- HyperEVM empty

Lockbox: `RateKind.ConvertToAssets` + `retainRateYield` + `maxRateJumpBps=300`. Configure checks live `asset()==DAI`. Never pin impl. Never `deposit`/`mint`/`withdraw`/`redeem` on the vault. User unwraps **gtDAI** and exits on Morpho.

Pilot cap **100k DAI** ≈ `DEFAULT_SHARE_CAP` 85_000 shares at the 1.176 rate. Share cap is frozen; do not raise it because the rate grew. Do **not** advertise APY.

`productionEvm=false`. `NotThisBatch`.
