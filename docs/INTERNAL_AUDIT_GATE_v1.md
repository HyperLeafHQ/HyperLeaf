# Internal audit — EpochHNestGate v1

Date: 2026-09-10. Branch: `feat/lz-oft-wrap`. Canonical tip is this branch, not PR #22.

## Do not advertise on live vault

Live NestVault `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` has **no** `depositGate` and is immutable. Direct `deposit()` still mints transferable hNEST immediately. Weekly HYPE isolation exists only after `EpochHNestGate` is the real deposit path (frontend routing now; one-shot `setDepositGate` on a **future** vault).

## P0 — must be green before SuperGrok / grokbot deploy

| # | Gate | Status on wrap |
|---|------|----------------|
| 1 | `forge test` compiles and the Gate + Nest suites pass | Gate 17 + NestVault 41 + hardening 5 |
| 2 | `allocateHype(0)` cannot seal the week; `finalizeHype` only after `epochEnd+1d`, permissionless so keeper death cannot trap hNEST | Done |
| 3 | Live has no Gate — copy / UI must not claim weekly HYPE isolation until Gate is deployed in front of deposits | Documented here + NEST_PRODUCT_POLICY |
| 4 | Tip includes PR #22 8d mint delay **and** `feat/hnest-yield-fee-gate-accounting-fix` residual index | Merged into `EpochHNestGate.sol` |
| 5 | Permissionless `rollEpoch` + `deposit` auto-rolls when the week has ended | Done |
| 6 | Fee bps + fee recipient snapshotted at epoch open; later `setFee` / `setFeeRecipient` do not rewrite a closed week | Done |

## P1 — before TVL scale

- Adapter freeze while live (already: `setHevAdapter` reverts `HevAdapterChangeWhileLive`)
- Real HEV fork: deposit → queue → dettach → 26w (still excluded from default `forge test`)
- 8d mint delay retest: late deposit, second deposit extends delay
- `depositGate` ops: one-shot, cannot clear; live vault will never have it
- Harvest / process gas vs HyperEVM 3M before raising the cap
- `bookVerifiedYield` still trusts `pendingLockedNestShare`, capped at 10% of TVL per Thursday week — not trustless

## Abandoned / superseded forks

| Branch / PR | Disposition |
|-------------|-------------|
| PR #22 `feat/nest-8d-withdraw-gate` | Superseded. Had allocate(0) seal, roll stall, no guardian, no residual, live fee (no snapshot), tests didn't compile (8 vs 9 epoch fields). |
| `feat/hnest-yield-fee-gate-accounting-fix` | Residual + snapshot + auto-roll **ported**. Do not merge that main-based tree onto wrap. |
| `feat/epoch-hnest-gate` / `feat/hnest-yield-fee-gate` | Older. Ignore. |

## What Gate is

```
deposit NEST → EpochHNestGate → NestVault mints hNEST to Gate
                ↓
         wait max(deposit+8d, epochEnd+30m)
                ↓
         keeper allocateHype (optional, amount>0)
         anyone finalizeHype after epochEnd+1d
                ↓
         user claims circulating hNEST + epoch HYPE + residual HYPE
```

8d mint delay is the product. 4d HEV dettach is a different clock.
