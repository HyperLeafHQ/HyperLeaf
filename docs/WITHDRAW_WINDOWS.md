# Withdraw windows & idle NEST buffer (MVP)

**Date:** 2026-09-03 (Asia/Shanghai UTC+8)  
**Status:** Implemented in NestVault — unit-tested; not an audit package yet.

## Problem (mainnet Nest)

1. While a veNFT is **attached** to HEV, `getNftState` reports `locked.amount = 0` and `locked.end = 0`. Unlock readiness must **not** use those fields.
2. `Voter.dettachFromManagedNFT` → `onDettachFromManagedNFT` sets lock end to `maxUnlockTimestamp()` ≈ **now + 26 weeks**, wiping the original timed end.
3. HEV `detachmentLockDuration` = **4 days** (HEV on-chain, we do not control it). NestVault gates `dettachForLiquidity` at **8 days** because the NEST reward cycle is 7 days. 4 days was wrong.
4. Therefore liquid NEST for the withdraw queue is **not** “wait until original createLock end”. Eager dettach on every `requestWithdraw` would reset a fresh 26w clock and is unsafe for UX.

## Design choice — idle buffer funded by deposit skim (safer MVP)

| Option | Pros | Cons |
|--------|------|------|
| **A. Portion of each deposit kept idle** (`idleDepositBps`) | Automatic, on-chain, no keeper capital; users fund shared liquidity proportionally | Slightly less NEST in HEV / ve yield |
| B. Keeper/owner top-up only | Max capital in HEV | Relies on off-chain capital & ops; buffer can go dry |

**Pick A as primary**, with **optional keeper `topUpIdle`** as secondary refill after large outflows. Absolute floor `minIdleNest` (owner/guardian) is always reserved: fulfillments only spend `balance - minIdleNest` so processing never leaves the buffer underfunded.

Justification: withdraw liquidity is a solvency property and should not depend on a keeper privately holding NEST. Skim is explicit, configurable, and pause-compatible.

## Accounting (explicit, vault-tracked)

- `totalNestLocked` — hNEST liability backing (unchanged meaning).
- `nestPrincipal[tokenId]` — NEST locked into that NFT at deposit (or residual). **Never** read attached `getNftState.amount` for readiness or sizing.
- `attachedAt[tokenId]` — timestamp when vault recorded attach (8d vault dettach gate).
- `unlockEligibleAt[tokenId]` — set on vault-initiated dettach to `block.timestamp + 26 weeks` (mirrors live `onDettach` reset). `veNEST.withdraw` only after this and `!isAttached`.
- Idle NEST = ERC20 balance on the vault (skim + top-ups + unlocked principal). No trust in attached NFT fields.

## Flows

```
deposit(amount)
  idlePart = amount * idleDepositBps / 10_000
  lockPart = amount - idlePart
  lockPart > 0 → createLockFor(lockPart, …, managedId=1) + adapter; record nestPrincipal, attachedAt
  idlePart stays as vault NEST balance
  totalNestLocked += amount; mint hNEST

requestWithdraw(hNest)   // whenNotPaused — NO dettach. Hidden backstop, not the product exit.
  burn hNEST; enqueue; totalNestLocked -= nestAmount

dettachForLiquidity(tokenIds)  // keeper only, when queue needs liquidity
  require now >= attachedAt + 8 days
  adapter.withdrawVeNFT → Voter.dettachFromManagedNFT
  unlockEligibleAt = now + 26 weeks
  clear inHev

harvest / processWithdrawQueue
  withdraw any NFT with now >= unlockEligibleAt && !isAttached (use nestPrincipal for books)
  fulfill queue FIFO from availableIdle = balance - minIdleNest only
```

## Pause

Unchanged: pause blocks `deposit` and `requestWithdraw`. Keeper may still harvest / process / dettach / topUpIdle.

## HYPE claim

Unchanged honesty: no invented HYPE/MEGAHYPE path; adapter `claimHype` is balance-sweep only.

## Remaining gaps (pre-audit)

- Voter vote-delay / dettach lock window eth_call coverage on fork
- Exact week-rounding of `maxUnlockTimestamp` vs vault `+ 26 weeks`
- Idle BPS / minIdleNest parameter governance + monitoring runbook
- End-to-end fork: deposit → queue → dettach → 26w → fulfill with real NEST
- Reentrancy / donation edge cases on idle balance; share-price vs idle donations
