# hsFF — later (2026-09-11)

Wrap **flexible sFF** only. Official Falcon staked FF on Ethereum:

- `0x1a0C3FfCbd101c6f2f6650DED9964c4A568C4D72`
- `asset()` = FF `0xFA1C09fC8B491B6A4d3Ff53A10CAd29381b3F949`
- 18-dec. `convertToAssets(1e18)` ~ 1.009 (RPC 2026-09-10)
- `cooldownDuration()` = **259200** (3 days). `cooldown()` already denylisted
- Supply ~1.37e26. HyperEVM empty

Lockbox: `RateKind.ConvertToAssets` + `retainRateYield` + `maxRateJumpBps=300`. Configure checks live `asset()==FF`. Never pin impl. Never start cooldown. Never `claimRewards` poke — that selector is also QUID’s `0x9a99b4f0`.

Do **not** wrap: raw FF, **sFF-Prime** `0x41FF…` (180d NFT), FF Staking Vault `0x1E7f…`.

Do **not** advertise 0.1% or Prime 5.22%. Miles are not NAV.

`productionEvm=false`. `NotThisBatch`.
