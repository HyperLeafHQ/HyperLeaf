# hNEST epoch and mint-delay policy

## Canonical timing

HyperLeaf keeps the Nest reward/accounting period at **7 days**. The 7-day period is the economic epoch and must not be changed by keeper timing or an admin-set epoch length.

The Gate adds a **1-day settlement buffer**, so the earliest epoch-level claim boundary is **8 days after epoch start**. In addition, every user's most recent deposit in that epoch gets its own **8-day minimum mint delay**. The effective user release time is the later of:

`depositTime + 8 days`

and

`epochStart + 8 days`

This means a late deposit cannot become circulating hNEST merely because the weekly epoch is about to end.

## Why 4 days is different

The HEV `detachmentLockDuration` is **4 days**. That value belongs to the managed veNEST NFT detach path in `NestVault` / `HevAdapter`. It is not the hNEST mint-delay and should not be used as the user-facing epoch lock.

For withdrawals, the vault still waits for the HEV detach gate and then tracks the post-detach lock reset separately. See `docs/WITHDRAW_WINDOWS.md`.

## State flow

```text
Deposit
  -> current 7-day Nest epoch
  -> hNEST remains inside EpochHNestGate
  -> Nest epoch closes
  -> keeper finalizes that epoch's HYPE allocation
  -> user's 8-day mint delay expires
  -> user claims hNEST + that epoch's HYPE
  -> hNEST becomes an ordinary transferable ERC-20
```

The Gate is therefore a **mint-delay mechanism, not a transfer lock**. Once claimed, hNEST can be transferred to a DEX, LP, market, or other holder without special token semantics.

## Invariants

1. `epoch.end - epoch.start == 7 days` for every epoch.
2. `epoch.claimableAt - epoch.start == 8 days`.
3. A user's epoch claim cannot succeed before `userClaimableAt`.
4. A second deposit by the same user in an epoch can only move `userClaimableAt` later, never earlier.
5. An empty epoch cannot be rolled early; epoch boundaries must not drift simply because the keeper acted early.
6. The 4-day HEV detach gate is independent from the 7-day Nest epoch and 8-day hNEST mint delay.
