# Pre-market guarantee

On `main` since `645a0d8`. HyperEVM canary is live (claims with USDM). Settlement Leaf **hVAR** is not listed yet.

Issue [#67](https://github.com/HyperLeafHQ/HyperLeaf/issues/67). First market: **Variational points**.

## Trust: resolver is the key

`MultisigResolver.resolve(marketId, token, rateX18)` is `onlyOwner`, one-shot. It can name **any** ERC-20 as `officialToken`. After resolve, a seller who delivers that token settles; buyers redeem it; the seller withdraws the USDM/sUSDM escrow. There is no on-chain check that `token` is “real VAR”.

That is not a theft bug in Factory/Escrow. It is the resolution trust root.

- Canary: owner is the protocol EOA (`Ownable2Step`).
- Before TVL / external size: transfer resolver ownership to a **Safe**, then `acceptOwnership`. No contract change.
- Frontend must say: HyperLeaf posts the settlement token and rate. Do not treat this as an oracle.

`voidMarket` is the same key. A voided market can never resolve.

## Product
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

Do not merge more origin chains into this Factory. One Factory = one remote origin / one lockbox until routing is per-market.
