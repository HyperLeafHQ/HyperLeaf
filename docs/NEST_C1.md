# NestVault C1 — `feat/nest-c1`

Replaces live v1 `0x4f6615…` for product use. v1 has only test TVL — abandon, do not patch.

## Product

- C1: **no redeem**, no idle buffer, full lock, HEV attach, `withPermanentLock=true`.
- Deposit only through `EpochHNestGate` (8d mint delay). Exit is Leaf Market.
- After each Thursday epoch anyone may `claimMerkle(proof, cumulativeAmount)` using [Nest's public API](https://app.usenest.xyz/api/liveprograms/api/hype-distribution/merkle-proof/{address}). The leaf pays **the vault**, never `msg.sender`.
- Inbound WHYPE is **not** holder yield until `settleInboundHype` takes **1%** (`feeBps`). Third-party claims to the vault are the same: anyone can settle.
- `bookVerifiedYield` raises `totalNestLocked` so later deposits are **not 1:1**. Gate still isolates weekly HYPE for new vs old holders.

## Not in this vault

No `requestWithdraw`, no dettach queue, no migrator from v1.
