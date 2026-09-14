# NestVault C1 — `feat/nest-c1`

Replaces live v1 `0x4f6615…` for product use. v1 has only test TVL — abandon, do not patch.

## Product

- C1: **no redeem**, no idle buffer, full lock, HEV attach, `withPermanentLock=true`.
- Deposit only through `EpochHNestGate` (8d mint delay). Exit is Leaf Market.
- After each Thursday epoch anyone may `claimMerkle(proof, cumulativeAmount)` — same call as live tx [`0x301ae5e5…`](https://hyperevmscan.io/tx/0x301ae5e59222205518963eb813e8334b73cc5989a6fc3f157b01063effb0a7d9): `0x33afCe…claim(0xca21b177)` with `addr_` = vault. Proof length is **not fixed** (that week was **11** leaves, not 12). API: `GET https://app.usenest.xyz/api/liveprograms/api/hype-distribution/merkle-proof/{vault}`.
- Token received is **WHYPE**. Nest UI may say MEGAHYPE; the transfer is WHYPE `0x555…555`.
- Direct `Merkle.claim(proof, vault, amount)` by a third party is the same money; `pendingResidualHype` already shows the net-of-fee, and `claimResidualHype` / `settleInboundHype` take the 1%.
- Deposit settles inbound WHYPE **before** minting (M-04) so a new depositor cannot take prior holders' unclaimed week. It also pays the caller's accrued pending WHYPE first (R2-F1) — normally a no-op because the gate syncs residual in the same tx, but it protects gate-migration / failed-sync edge paths from stranding pending WHYPE via the post-mint debt overwrite.
- Sub-distributable WHYPE dust (below one acc-share unit) settles nothing — no fee, no event; the fee is deferred until the dust distributes (R2-F2).
- Rounding dust stays unaccounted (`hypeAccounted` only rises by what `accHypePerShare` can pay) and rolls into the next settle (L-03).
- `onERC721Received` accepts veNEST only. Owner may `recoverERC721` a stray token; registered veNEST cannot be pulled (L-04).
- Pause freezes deposits only. Merkle/settle stay live.
- Unsolicited WHYPE is treated as campaign yield (1% fee) — accepted (audit M-02).
- Inbound WHYPE is **not** holder yield until `settleInboundHype` takes **1%** (`feeBps`). Third-party claims to the vault are the same: anyone can settle.
- `bookVerifiedYield` raises `totalNestLocked` so later deposits are **not 1:1**. Gate still isolates weekly HYPE for new vs old holders.
- First-deposit capture: WHYPE that lands before the first deposit (donation, early merkle claim) settles right after the first mint — net goes to the sole holder (the gate, which redistributes via its residual index), 1% fee to `feeRecipient`.
- **No ERC20 rescue.** There is no `recoverERC20`; any non-WHYPE token or direct NEST transfer to the vault is stranded by design.
- Deposits revert during Nest Voter distribution windows (first/last hour of the weekly epoch, ~Thursday 00:00 UTC boundaries) — expected; schedule around them.
- `bookVerifiedYield` pagination: once `veNFTIds.length` approaches **~150**, keepers must use `bookVerifiedYield(start, end)` — the full sweep bricks around ~200-300 NFTs under HyperEVM's 3M small-block gas limit. The weekly 10% book cap accumulates across paginated calls.
- `setFee` has **no timelock** — owner policy: announce fee changes ahead of weekly settlements.
- Keeper runbook: see `docs/DEPLOYMENT_CHECKLIST.md` ops notes (a)-(i).

## Not in this vault

No `requestWithdraw`, no dettach queue, no migrator from v1.
