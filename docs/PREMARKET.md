# Pre-market guarantee — `feat/premarket`

Standalone. Zero imports from Nest / Gate / Leaf Market. Not a batch. Not `main`.

Issue [#67](https://github.com/HyperLeafHQ/HyperLeaf/issues/67). First canary: **Variational points**.

## Product

- Ticker `hPre{Token}Pts{tier}x{price}` — `hPreVarPts2x20`, `hPreVarPts1x20`. **Display only.** Orders, fills, and settlement key by `seriesId`. Two books at $17 and $17.50 can share a ticker; they never share an id.
- Tiers **{1x, 2x} only**. 1x so sellers list; 2x is the HyperLeaf guarantee.
- Deal price is **free discovery** (any ≥ $1). Chain must not reject a $17 book. UI aggregates depth by `(price, tier)`, routes to a specific `seriesId`.
- Users pay **USDM** (6 dec). The vault wraps to Monetrix **sUSDM** `0x5f1ab62C3159eBE04aFF14Beef84b0b60de63DDF`. Exit pays **sUSDM**; the user unwraps if they want USDM.
- Get USDM: mint 1:1 from HyperEVM USDC via Monetrix (`USDC 0xb883…` → `USDM 0xE2d2…`). The app should send USDM, not sUSDM.
- Optional second market: Delpho **sUSDV** via `SUSDV` env (same wrap-from-USDV pattern) once the stake token is confirmed.
- Books are in **underlying NAV**. Share-price growth is protocol income (`harvest` surplus shares; never redeem — sUSDM unstake has a cooldown).
- Each series has its own share bag. A falling sUSDM rate cannot `Shortfall`-freeze other series' mint/buy.
- If a series is underwater, `release` splits remaining shares pro-rata by remaining booked NAV. First redeemer does not take the bag.
- `DELIVERY_WINDOW = 48h` from `resolve()`. `EXPIRY = 365d`. `RESOLVE_GRACE = 48h`.
- Resolution key is `MultisigResolver` (Owner EOA for canary; wrap in a Safe before TVL). One-shot resolve/void.

## How much USDM (1x / $20)

| | 1 claim (`1e18`) of `hPreVarPts1x20` | 1 claim of `hPreVarPts2x20` |
|---|---|---|
| Seller sends | **20 USDM** | **40 USDM** |
| Buyer sends | **20 USDM** | **20 USDM** |
| Vault wraps | `sUSDM.deposit(USDM)` | same |
| Exit | sUSDM shares covering booked NAV | same |

At ~1.025 USDM per 1e12 shares, 20 USDM mints ~19.51e12 sUSDM. Quote:

```
(assets, shares) = factory.previewDepositAndMint(seriesId, claimAmount)
(assets, shares) = factory.previewBuy(seriesId, claimAmount)
```

Approve **USDM** `assets`. Pass `shares` as `maxShares` (small buffer OK). Wrap rate worse than quote → `Slippage`.

## How much sUSDM (legacy note)

Do **not** deposit sUSDM. The factory pulls USDM and wraps.

Exit pays booked NAV in sUSDM. Extra share-price growth is `harvest` → feeRecipient. A falling rate can pay out below the original USD on *that* series only.

## Deploy

`script/DeployPremarketVar.s.sol` — factory + resolver + lockbox + VAR market on sUSDM. `SUSDV=` adds a second market. Does not mint series. Owner `acceptOwnership` on resolver / factory / lockbox. `setLockbox` and lockbox `setFactory` are one-shot. `setFeeRecipient(marketId, addr)` updates an existing vault.

Sellers `createSeries`. Frontend lists by `seriesId`.

## Nado points (next market, n=3)

Same factory `0x22684F6e63525d009d7cAb9415B0680Fe4aF8f6A`. Owner `createMarket("Nado points", "Nado", sUSDM)` only when `marketsCreated() == 2`. Predicted `marketId` =

`keccak256(abi.encode("Nado points", sUSDM, 3))` = `0x9486988cc36ef76e88b1607554932525fbefc3a2101c4dde123fe67fd22e3bca`

Script: `script/CreatePremarketNado.s.sol`. **Do not broadcast** until a human `GO`. If another market already consumed n=3, abort — do not reuse this id.

Settlement Leaf is **hINK**, not a NADO token. Official INK ERC-20 is not posted. Conversion ratio stays parameterized at `resolve()`. Ink LZ V2 is ready (eid 30339, Endpoint `0xca29f3A6…` not CREATE2). Do not `DeployAdapter` until the token exists.

Do not merge to `main` until a VAR series has been smoke-filled on HyperEVM.

## Quantus QTC (native OTC — not a market on the live factory)

Quantus has no smart contracts. QTC cannot be `officialToken`. Do **not** `createMarket` on `0x22684F6e…`.

Phase 1 is a **new** bilateral RFQ:

`NativeOtcFactory` + `NativeDeliveryResolver`

- Seller posts USDM collateral (wrapped to sUSDM, same vault as VAR).
- Buyer takes the offer, names a Quantus dest, posts USDM payment.
- Seller sends QTC on Quantus. Owner Safe attests `(offerId, txHash, destHash, atoms)`.
- `settle` pays seller payment + collateral. Miss the 48h window → buyer takes both.
- Protocol never holds QTC. Never `hQTC`. Never principal inventory.

Script: `script/DeployNativeOtcQtc.s.sol`. **Do not broadcast** until a human `GO`. Owner `acceptOwnership` on resolver + factory after deploy.

Only unlocked / mined QTC. Investor + team 23% is 1y locked — do not attest those allocations.

