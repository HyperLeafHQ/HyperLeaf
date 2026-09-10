# NEAR / stNEAR — later (2026-09-11)

Do **not** wrap raw NEAR or wNEAR. Native stake is a pool account (`meta-pool.near`), not an EVM receipt.

Wrap **Aurora STNEAR** only (Rainbow-bridged Meta Pool stNEAR, 1:1 with NEP-141):

- Aurora `0x07F9F7f963C5cD2BBFFd30CcfB964Be114332E30` — 24 decimals, symbol `STNEAR`
- Supply on Aurora ~1.12e29 atoms (~1.12e5 STNEAR). Native price `get_st_near_price` ≈ **1.504 NEAR / stNEAR**
- Canonical NEP-141: `meta-pool.near` (NEAR, 24-dec)
- Delayed unstake ~4 epochs / 24–72h stays on Meta Pool. Liquid unstake is a fee swap — lockbox never does either
- Never `stAUR` (AURORA staking). Never Linear / Rhea this listing

LayerZero: **Aurora eid 30211** (not native NEAR). Labs + Horizen + Canary v2 exist. HyperEVM empty.

## Blockers

1. **24 decimals.** Current OFT / `shareScale` only scales *up* (hLBTC 8→18). 24→18 needs a divisor or dest 24-dec. Do not deploy until that path exists.
2. **No rate on the ERC-20.** Yield is share-price on NEAR. First wrap is `RateKind.None` (yield stays in the receipt). 1% skim needs an Aurora-readable price — not this round.

`NotThisBatch`. After 24-dec support. Do not advertise liquid-unstake APY.
