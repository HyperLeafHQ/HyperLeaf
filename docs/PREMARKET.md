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

## How much sUSDM (1x / $20)

Do **not** deposit “20 sUSDM”. The book is **20 USDM of NAV**.

| | 1 claim (`1e18`) of `hPreVarPts1x20` | 1 claim of `hPreVarPts2x20` |
|---|---|---|
| Seller locks | **20 USDM** NAV | **40 USDM** NAV |
| Buyer pays | **20 USDM** NAV | **20 USDM** NAV |
| Token pulled | `sUSDM.convertToShares(NAV)` rounded up | same |

sUSDM is 12 decimals, USDM is 6. At a 1.00 exchange rate, 20 USDM = `20e12` sUSDM shares. If the vault has grown to 1.05 USDM per share, the same 20 USDM book pulls fewer shares (`~19.05e12`).

Quote on-chain before signing:

```
(assets, shares) = factory.previewDepositAndMint(seriesId, claimAmount)
(assets, shares) = factory.previewBuy(seriesId, claimAmount)
```

`assets` is USDM/USDV (6 dec). `shares` is what the wallet must `approve` and send.
Mint/buy take `maxShares` and revert `Slippage` if the live 4626 rate would pull more than the quote.

Exit pays that **booked NAV** back in shares at the then-current rate. Extra share-price growth is `harvest` → feeRecipient. A falling rate (sUSDV) can pay out below the original USD.
- If NAV falls (sUSDV negative funding), exits still pay remaining shares; USD value can be below book. Disclosed.
- `DELIVERY_WINDOW = 48h` from `resolve()`. `EXPIRY = 365d`. `RESOLVE_GRACE = 48h`.
- Resolution key is `MultisigResolver` (Ownable2Step; wrap in a Safe before TVL).

## Deploy

`script/DeployPremarketVar.s.sol` — factory + resolver + lockbox + VAR market on sUSDM. `SUSDV=` adds a second market. Does not mint series. Owner `acceptOwnership`. Sellers `createSeries`.

Do not merge to `main` until a VAR series has been smoke-filled on HyperEVM.
