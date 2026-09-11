# Pre-market guarantee (hPerVarPts) — feat/premarket

Standalone. Zero imports from Nest / Gate / Leaf Market. Not a batch. Not main.

Issue [#67](https://github.com/HyperLeafHQ/HyperLeaf/issues/67) v3 + audit [5635942604](https://github.com/HyperLeafHQ/HyperLeaf/issues/67#issuecomment-5635942604).

## Product decisions (audit P1s)

1. **Seller-held claims at terminal are unsold inventory.** Factory inventory and the seller's own balance are burned before the snapshot. They get collateral back as excess (same as unsold), **not** a share of the payment pool or the default penalty. Remaining external holders get the pools. Affiliates can still reacquire — disclosed, not solvable without KYC. Honest path is `burnClaims` before terminal.
2. **SETTLED asset is the resolver `officialToken` on the settlement chain.** That ERC-20 is what holders receive. Cross-chain lockbox may only credit that same token. Origin lock is how the token gets here, not a second ticker. Bridge risk is the lockbox of that token, Section 12.
3. **~1% refund variance is primary-fill only** (Leaf Market 1% buyer reward). Direct `buyFromSeries` has no reward. Secondary purchase price is never refunded.

First canary: **Variational points** (`hPerVarPts-{price}-{1|2}X`). Tiers **{1x, 2x} only** — 1x so sellers will list; 2x is the HyperLeaf guarantee. No 3x.

## Constants

`DELIVERY_WINDOW = 48h` from series `resolve()`. `EXPIRY = 365d` from first mint. `RESOLVE_GRACE = 48h`. Tiers {1x, 2x}. Floors $1. Protocol take = 100% of vault surplus (interest). No claim deadline.

## Example

`hPerVarPts-20-2X` — Variational points, $20/pt, 2x. Collateral $40/claim. Not a Leaf.
