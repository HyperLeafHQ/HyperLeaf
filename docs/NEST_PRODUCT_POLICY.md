# hNEST Product Policy

## Decision

**Current product (not yet open for deposits):** `NestVaultC1` + `EpochHNestGate` (8d mint) + Leaf Market occupancy skim.

Abandoned immutable deployments — do **not** point the frontend or bot at these:

- v1 NestVault `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` (test TVL, 6-month redeem, no merkle fee)
- First C1 `0x4a508cc55608ae37A2c68D803D817A72B02064Fe` (snapshot HYPE; superseded by time-weighted accounting)

A new C1 + Gate + Market must be deployed from `feat/market-nest-occupancy` (or its successor) **before** `setDepositsEnabled(true)`. Leaf Market must `setNestHypeVault(newHNest, newVault)` in the same rollout (`NEST_VAULT` on `DeployClaimDest`).

Time-weighted HYPE: Thursday WHYPE is split by balance-seconds. At most one closed epoch per 7 days (dust intra-week uses the snapshot fallback). Cancel on Leaf Market is instant; listed-time WHYPE forwards to `feeRecipient`.

The old v1 `requestWithdraw` path is **not** part of this product.

## Why C1-style

The veNEST lock is ~26 weeks. Almost nobody will wait that long for protocol redeem — they would have staked NEST themselves. The product exit is therefore the secondary market.

## User-facing behavior

- hNEST remains a normal transferable ERC20.
- The primary exit is the secondary market: sell or otherwise transfer hNEST to a buyer who wants the underlying Nest position.
- The frontend / app must **not** expose a redeem, withdraw, or exit-to-NEST window for normal users.
- Product copy should emphasize the underlying lock, liquidity conditions, market price, and the fact that HyperLeaf does not guarantee an NAV floor or secondary-market buyer.
- The absence of a redeem button is a product-policy choice, not a claim that the contract lacks redemption functionality.

## Protocol-level behavior

The existing `NestVault.requestWithdraw(hNestAmount)` path remains deployed and callable directly on-chain. It is retained as a **manual / emergency / backend backstop** and must not be marketed as the preferred user journey.

Its existing operational constraints still apply:

- hNEST is burned when a redemption request is accepted;
- the request enters the existing withdrawal queue;
- liquidity may depend on the idle NEST buffer and keeper-driven veNEST detachment;
- HEV / Nest timing can make the practical exit substantially slower than a market sale.

Therefore the product can behave like C1 without changing the immutable live Vault.

## Two clocks (do not share)

Live HyperEVM, probed 2026-09-10:

| Clock | Value | What it gates |
| ----- | ----- | ------------- |
| **HEV `detachmentLockDuration()`** | **4 days** (`345600`) | `Voter.dettachFromManagedNFT`. Custody. We do not control HEV. |
| **Live NestVault `0x4f6615…` `DETACHMENT_LOCK_DURATION()`** | **4 days** (`345600`) | Keeper `dettachForLiquidity` only. Same as HEV. Immutable. |
| **Nest epoch** | **7 days**, Thursday 00:00 UTC | HYPE / NEST reward accounting. Keeper harvests 00:30 UTC. |
| **hNEST circulation gate** | `max(deposit + 8 days, epochEnd + 30 minutes)` | When a new deposit's hNEST is economically “epoch-settled” for secondary-market transfer. **Not** a dettach lock. |

`HNestCirculation.claimableAt(depositTs)` is the formula. Do **not** write `claimableAt = deposit + 8 days` alone, and do **not** fold 8 days into `dettachForLiquidity`.

At Day 4 the underlying veNEST is technically dettachable. hNEST from that deposit is still inside the circulation window until Day 8 / epoch settlement. That split is intentional: we do not use HEV's 4 days to prove a reward epoch has finished.

Live vault mints transferable hNEST on deposit and cannot be patched. **Do not advertise weekly HYPE isolation on 0x4f6615…** until `EpochHNestGate` is the actual deposit path.

Safe to say: HyperLeaf's gated deposit path applies the 8-day circulation rule.
Not safe to say: hNEST itself is always subject to the 8-day rule. The token has no provenance bit.

Same-user deposits in one epoch are independent tranches (`claimTranche`). A later deposit does not delay an earlier one.

`allocateHype` is keeper-supplied HYPE, not an on-chain Nest harvest proof. `bookVerifiedYield` is adapter-bounded (10%/week), not canonical.

New HyperLeaf deposits (when Gate is wired):

- guardian can pause; only owner unpauses
- `rollEpoch` is permissionless; `deposit` auto-rolls after the week ends
- `allocateHype(amount=0)` is rejected; `finalizeHype` is permissionless after `epochEnd + 1 day`
- fee bps / recipient are snapshotted when the epoch opens
- vault residual HYPE earned while Gate holds hNEST is a separate index (accounting-fix)
- Future vaults: `setDepositGate` is one-shot and cannot be cleared. Live `0x4f6615…` has no such setter.

C1 has no `requestWithdraw`. Exit is Leaf Market only.

## Detach (4 days, HEV custody)

- **Live + this source:** `DETACHMENT_LOCK_DURATION = 4 days`, matching HEV.
- **Tests:** 4d−1 reverts `DettachTooEarly`. Exactly 4d is the first legal dettach. 4d dettach is still before `HNestCirculation.claimableAt`.

## `ownerTransferVeNFT`

Repo source includes an owner-only veNEST custody transfer that **decrements `totalNestLocked`** by that NFT's principal + booked yield. Remaining hNEST is diluted unless matching supply is burned off-path.

This function **does not exist** on the already-deployed live vault. It cannot move mainnet test funds already sitting in `0x4f6615…`. Those funds stay in that vault; the C1 product layer is how users exit (secondary market). Any future vault replacement is a separate migration.

## Security and accounting posture

Keep: adapter freeze while live, bounded HYPE epoch close (7d min), batched user HYPE checkpoint (52/tx), zero-share deposit guard, HEV vault freeze while NFTs are deposited.

v1 `0x4f6615…` is abandoned. Do not revive it as the current product. Do not wire Gate to it.

## Frontend integration rule

For the current hNEST listing (after the replacement C1 is live and deposits are enabled):

```text
Deposit NEST
    ↓
EpochHNestGate (8d) → NestVaultC1
    ↓
hNEST (claim after delay)
    ↓
Hold / Leaf Market
    ↓
Primary exit = Leaf Market (occupancy WHYPE → protocol)
```

Do not show redeem/withdraw. Do not send users to `0x4f6615…` or the first C1.

## Deployment rule

Deploy `NestVaultC1` + Gate + **new** Leaf Market together. Pass `NEST_VAULT` to `DeployClaimDest` so occupancy cannot stick in the Market. Do not tell grok bot to "upgrade" an already-broadcast C1 — it is immutable; a semantics change is a replacement set.
