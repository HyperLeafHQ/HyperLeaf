# hsGHO — later (2026-09-11)

Aave App “up to 6.25%” is **not** a listing. It is a phone savings shell (ERC-6900 + Stable Vault + referral boosts). No transferable receipt. Boosts are in-app.

Wrap **sGHO** only. Official ERC-4626 on Ethereum:

- `0xE1753F2e00940cC31213dd92013cF019DFE4ca1d`
- `asset()` = GHO `0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f`
- Instant redeem, no slash, no cooldown
- `convertToAssets(1e18)` ~ 1.0138 (RPC 2026-09-10)
- Supply ~1.62e26 shares / ~1.64e26 GHO
- HyperEVM empty. ETH LZ already in the stack

Lockbox: `RateKind.ConvertToAssets` + `retainRateYield` + `maxRateJumpBps=300`. Configure checks live `asset()==GHO`. Never pin impl.

Do **not** wrap: raw GHO, App basket, Arb aUSDC/aUSDT, Merit/legacy sGHO, Umbrella `stkwaEthUSDC.v1` (that is `hstkwaUSDC`).

Do **not** advertise 6.25%. User gets sGHO NAV, not App boosts.

`productionEvm=false`. `NotThisBatch`.
