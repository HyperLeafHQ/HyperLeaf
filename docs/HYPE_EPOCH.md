# hNEST yield split — why a mint-delay gate, not “MasterChef everyone”

Updated: 2026-09-07.

## Two Nest income streams

| Stream | Who Nest actually pays | HyperLeaf handling |
|---|---|---|
| Weekly NEST compound (lock gets thicker) | Every locked veNEST, same weight | `bookVerifiedYield`: **1% hNEST to protocol, 99% NAV to holders**. Never `recordCompound(uint)`. |
| Weekly HYPE | Only veNEST that **increased this epoch** (new deposits + this week's compound increment) | New-deposit slice → `EpochHNestGate`. Compound-increment slice → residual MasterChef on seasoned hNEST, when a claim path exists. |

`feeBps = 100` (1%) on **yield only**. Deposit / withdraw have no protocol fee (user pays gas / LZ).

## Claude's MasterChef-for-all proposal

Claude's idea: drop the gate, keep hNEST freely transferable, and let every holder claim HYPE for the epochs they held (standard `accHypePerShare` + transfer debt).

That is the right design **if** HYPE were a holding-time reward. Nest's HYPE is not that.

Nest pays HYPE to **new veNEST this week**. If HyperLeaf then MasterChef that blob to whoever currently holds hNEST:

- DEX buyers of **old** hNEST collect HYPE that was earned by **this week's depositors**
- New deposits get diluted → people stop depositing into HyperLeaf and just lock on Nest
- Transfer checkpoints cannot reconstruct “this unit of hNEST is this week's new principal” because ERC-20 is fungible

Claude also argued the gate would lock hNEST transfers and break DEX integration. **That is a misread of this gate.**

## What the gate actually does

`EpochHNestGate` sits **in front of minting**. It does **not** freeze circulating hNEST.

1. User deposits NEST into the gate.
2. NestVault mints hNEST **to the gate**, not the user.
3. After the Nest week, keeper allocates **that epoch's new-deposit HYPE** (1% protocol / 99% to those depositors).
4. User claims: **standard transferable hNEST** + HYPE.
5. From then on that hNEST is seasoned old principal. DEX / LP / transfer work like any ERC-20.

Circulating hNEST is always a vanilla ERC-20. The one-week wait is only on **new deposits**, which is the same week Nest uses to decide who earned the HYPE.

Pair with `NestVault.setDepositGate(gate)` so users cannot skip the wait by calling `vault.deposit` directly. Live vault `0x4f66…` does **not** have `setDepositGate` until a v2 redeploy; until then the gate is opt-in.

## What we will not do

- Do not lock hNEST transfers or make a non-standard ERC-20.
- Do not re-enable `recordCompound(uint256)` (HL-002).
- Do not dump the entire Nest HYPE payment into the gate (that would steal the compound-increment slice from seasoned holders) or into vault MasterChef (that would steal the new-deposit slice from the gate).
- Do not book NEST yield from idle donations / `topUpIdle`.

## Live vs this branch

| Contract | Live mainnet 999 | This branch |
|---|---|---|
| NestVault `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` | `recordCompound` disabled; 1% fee only if residual HYPE is swept (currently 0) | Adds `bookVerifiedYield` + `depositGate`. **Needs a new deploy to take effect.** |
| EpochHNestGate | Not deployed | Deployable in front of the live vault *without* a NestVault upgrade; cannot force-only-gate until v2. |
