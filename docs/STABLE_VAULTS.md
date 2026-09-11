# Stable vaults — 2026-09-10 chain check

Never wrap the stable. Wrap the **receipt**. HyperEVM empty on all four.

## hDAI — later, capped

Gauntlet DAI Core V1 `0x500331c9fF24D9d11aee6B07734Aa72343EA74a5` Ethereum.
`symbol=gtDAIcore` · `asset()=DAI 0x6B175474E89094C44Da98b954EedeAC495271d0F` · `convertToAssets(1e18)=1.17698e18` · `totalAssets≈2.135M DAI` (RPC 2026-09-11).

Wrap **shares** only. Cap **100k DAI** ≈ 85k shares. Do not advertise APY. Freeze `asset()==DAI`. Never Blue. Never Smokehouse DAI. `feat/hdai` · `docs/HDAI.md`. `productionEvm=false`.

## hRLUSD — later, same Morpho family

Sentora RLUSD Main V2 `0x6dC58a0FdfC8D694e571DC59B9A52EEEa780E6bf` Ethereum.
`symbol=senRLUSDv2` · `asset()=RLUSD 0x8292Bb45bf1Ee4d140127049757C2E0fF06317eD` · `convertToAssets(1e18)=1.01149e18` · `totalAssets≈353.7M` (RPC 2026-09-11).

Wrap **senRLUSDv2** only. Never RLUSD, never Blue. 1% skim. `feat/hrlusd` · `docs/HRLUSD.md`. `productionEvm=false`.

## BTWUSDT — research (BSC, CeDeFi)

Bitway Core Alpha share `0x73af543D809C8D3414e5B92b3aa2c25b182Ba3A1` on **BSC** (not a Bitway L1). Vault `0xb82E32…B63`, `paused=false`. Supply ≈23.9M. Official [staking contracts](https://docs.bitway.com/bitway-earn/staking-contracts).

Yield is Bitway strategy + **CEX custody**. Normal unstake ~7d; flash has a penalty. Token is **not** ERC-4626. Wrap **BTWUSDT** only, never USDT. Do not market as trustless. LZ eid 30102 exists; still not a BATCH.

## hHLV — watch. Only `HLV [USD1-USD1]`

Ticker is **hHLV**, not hUSD1. Inner is the perp LP share. USD1 is the unit of NAV, not the wrapped token.

Config that keeps our books 1:1 in **HLV** (PnL lives in HLV/USD1, not in `totalLocked`):

- `RateKind.None`
- `convertYieldToHype = true` (so `_harvestInner` is a no-op and redeem is 1:1 HLV)
- never `retainRateYield`
- never approve HertzFlow routers
- never poke `executeHlvDeposit` / `executeHlvWithdrawal` / HLV `mint` `burn` `deposit` `transferOut`

Ignoring trader PnL, remaining code risks: (1) a future transfer tax on HLV would underback the box on redeem; (2) `innerSupplyCeiling` must sit above live ~6.76e24; (3) do not point poke at the HLV address — it is also a Bank (`deposit`/`mint`/`burn`/`transferOut`).

User txs on BSC (2026-09-10 RPC):

- Deposit execute: [`0x8b441590…8184`](https://bscscan.com/tx/0x8b4415902782d3bd1419ff9c67b052766472a8a62c6fc08aa37b4507c3678184)  
  `0xB58B…3Bf4.multicall` → `executeHlvDeposit(0xd6b8546b)`. Mints **8.998 HLV** to `0xe0df…4cd3`.
- Withdraw execute: [`0xc472af4c…a779`](https://bscscan.com/tx/0xc472af4c610dc368959cd9e1661d7c6d63bc883d76b4940742a2fd6678d0a779)  
  `0xBA3A…65fa.executeHlvWithdrawal(0x55ceeb84)`. Burns **13.5 HLV**, user `0x8404…08db` gets **~14.19 USD1**.

| | Address | Role |
| --- | --- | --- |
| HLV receipt | `0xeeA83A77Eb978Be804Da038aEdd318dbFd3da9c6` | wrap this |
| HFUSD1 | `0x026c39ab4b07f4c8c62b5824f0f9d7be5087405a` | Hertzflow wrapped USD1 — do not wrap |
| HF Market | `0xf59b083e6b700f011475c70a2f81fa49378e28d3` | GM-style market — do not wrap |
| USD1 | `0x8d0d000ee44948fc98c9b98a4fa4921476f08b0d` | World Liberty — do not wrap |
| Deposit router | `0xB58BA4E284d48Fc689Bf209eb4E54009e71E3Bf4` | keeper `executeHlvDeposit` |
| Withdraw router | `0xBA3A1F7663500b4bEEb8c98E910b116D10AE65fa` | keeper `executeHlvWithdrawal` |

HLV is a transferable ERC-20. Protocol in/out is **async keeper**, not ERC-4626. Observed ~1.05 USD1 / HLV; **NAV can fall**. Leaf lockbox must **never** call HertzFlow routers. User unwraps HLV and exits on HertzFlow.

Still not a BATCH: no `convertToAssets`, perp drawdown, fork unwind untested.