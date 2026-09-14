# Pre-market guarantee — `feat/premarket`

Standalone. Zero imports from Nest / Gate / Leaf Market. Not a batch. Not `main`.

Issue [#67](https://github.com/HyperLeafHQ/HyperLeaf/issues/67). First canary: **Variational points**.

## Product

- Ticker `hPre{Token}Pts{tier}x{price}` — `hPreVarPts2x20`, `hPreVarPts1x20`.
- Tiers **{1x, 2x} only**. 1x so sellers list; 2x is the HyperLeaf guarantee.
- Deal price is **free discovery** (any ≥ $1). Chain must not reject a $17 book. UI aggregates by `(price, tier)`.
- Collateral: Circle native USDC on HyperEVM `0xb88339CB7199b77E23DB6E890353E22632Ba630f`.
- Protocol take = 100% of vault surplus (interest). No trade/settlement fee.
- `DELIVERY_WINDOW = 48h` from `resolve()`. `EXPIRY = 365d`. `RESOLVE_GRACE = 48h`.
- Resolution key is `MultisigResolver` (Ownable2Step; wrap in a Safe before TVL).

## Deploy

`script/DeployPremarketVar.s.sol` — factory + resolver + lockbox + **one** VAR market. Does not mint series. Owner `acceptOwnership`. Sellers call `createSeries`.

Do not merge to `main` until a VAR series has been smoke-filled on HyperEVM.
