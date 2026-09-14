# NestVault C1 — `feat/nest-c1`

Replaces live v1 `0x4f6615…` for product use. v1 has only test TVL — abandon, do not patch.

## Product

- C1: **no redeem**, no idle buffer, full lock, HEV attach, `withPermanentLock=true`.
- Deposit only through `EpochHNestGate` (8d mint delay). Exit is Leaf Market.
- After each Thursday epoch anyone may `claimMerkle(proof, cumulativeAmount)` — same call as live tx [`0x301ae5e5…`](https://hyperevmscan.io/tx/0x301ae5e59222205518963eb813e8334b73cc5989a6fc3f157b01063effb0a7d9): `0x33afCe…claim(0xca21b177)` with `addr_` = vault. Proof length is **not fixed** (that week was **11** leaves, not 12). API: `GET https://app.usenest.xyz/api/liveprograms/api/hype-distribution/merkle-proof/{vault}`.
- Token received is **WHYPE**. Nest UI may say MEGAHYPE; the transfer is WHYPE `0x555…555`.
- Direct `Merkle.claim(proof, vault, amount)` by a third party is the same money; `pendingResidualHype` already shows the net-of-fee, and `claimResidualHype` / `settleInboundHype` take the 1%.
- Deposit settles inbound WHYPE **before** minting (M-04) so a new depositor cannot take prior holders' unclaimed week.
- Pause freezes deposits only. Merkle/settle stay live.
- Unsolicited WHYPE is treated as campaign yield (1% fee) — accepted (audit M-02).
- Inbound WHYPE is **not** holder yield until `settleInboundHype` takes **1%** (`feeBps`). Third-party claims to the vault are the same: anyone can settle.
- `bookVerifiedYield` raises `totalNestLocked` so later deposits are **not 1:1**. Gate still isolates weekly HYPE for new vs old holders.

## Not in this vault

No `requestWithdraw`, no dettach queue, no migrator from v1.
