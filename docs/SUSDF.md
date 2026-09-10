# hsUSDf — later (2026-09-11)

Wrap **sUSDf** only. Official Falcon ERC-4626 on Ethereum:

- `0xc8CF6D7991f15525488b2A83Df53468D682Ba4B0` (proxy; impl `0x0d132bEE…3f34`)
- `asset()` = USDf `0xFa2B947eEc368f42195f24F36d2aF29f7c24CeC2`
- 18-dec. `convertToAssets(1e18)` ~ 1.134 (RPC 2026-09-10)
- Supply ~5.82e25 shares. HyperEVM empty. ETH LZ already in the stack

Lockbox: `RateKind.ConvertToAssets` + `retainRateYield`. Never `deposit` / `withdraw` / `redeem`. Never poke the rewards distributor `0x8AF2…`. Falcon’s daily 21:00–22:00 GMT+8 queue is theirs.

Do **not** wrap: raw USDf, FF, sFF, sFF-Prime, BSC USDf `0xb3b0…e9d2`.

Do **not** advertise 4.51% or any Falcon snapshot APY. Yield is strategy NAV and can go down; watermark does not.

`productionEvm=false`. `NotThisBatch`.
