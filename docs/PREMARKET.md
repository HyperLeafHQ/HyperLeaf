# Pre-market guarantee — `feat/premarket`

Standalone. Zero imports from Nest / Gate / Leaf Market. Not a batch. Not `main`.

Issue [#67](https://github.com/HyperLeafHQ/HyperLeaf/issues/67). First canary: **Variational points**.

## Product

- Ticker `hPre{Token}Pts{tier}x{price}` — `hPreVarPts2x20`, `hPreVarPts1x20`.
- Tiers **{1x, 2x} only**. 1x so sellers list; 2x is the HyperLeaf guarantee.
- Deal price is **free discovery** (any ≥ $1). Chain must not reject a $17 book. UI aggregates by `(price, tier)`.
- **Collateral is yield-bearing ERC-4626**, not idle USDC:
  - Default: Monetrix **sUSDM** `0x5f1ab62C3159eBE04aFF14Beef84b0b60de63DDF` (12 dec, asset USDM 6 dec).
  - Optional: Delpho **sUSDV** via `SUSDV` env once the stake token address is confirmed on-chain.
- Books are in **underlying NAV** (USDM/USDV). Users exit at that booked NAV. **Share-price growth while locked is protocol income** (harvest surplus shares; never redeem — sUSDM unstake has a cooldown).
- If NAV falls (sUSDV negative funding), exits still pay remaining shares; USD value can be below book. Disclosed.
- `DELIVERY_WINDOW = 48h` from `resolve()`. `EXPIRY = 365d`. `RESOLVE_GRACE = 48h`.
- Resolution key is `MultisigResolver` (Ownable2Step; wrap in a Safe before TVL).

## Deploy

`script/DeployPremarketVar.s.sol` — factory + resolver + lockbox + VAR market on sUSDM. `SUSDV=` adds a second market. Does not mint series. Owner `acceptOwnership`. Sellers `createSeries`.

Do not merge to `main` until a VAR series has been smoke-filled on HyperEVM.
