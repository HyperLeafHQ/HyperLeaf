# Audit fixes v1 — mapping HL-* → code

Date: 2026-09-06 (Asia/Shanghai). Source: `docs/INTERNAL_AUDIT_v1.md`.

| ID | Severity | Fix |
|----|----------|-----|
| **HL-001** | Critical (ops) | `docs/DEPLOYMENT_CHECKLIST.md`: Owner=user EOA; Guardian=user other EOA (pause only); Keeper=Hyperleaf `0xc321…5887`; feeRecipient separate; **never** deployer as Owner/Guardian. Ownable2Step handoff before open deposits. |
| **HL-002** | Critical | `NestVault.recordCompound` always `revert CompoundDisabled()`. Tests: deposit + unbacked compound reverts; cannot inflate withdraw liability. |
| **HL-003** | High | `dettachForLiquidity` caps cumulative `nestPrincipal` to `(pending−idle) * (1 + dettachBufferBps/1e4)`. Owner `setDettachBufferBps` (max 5000). Tests: over-dettach prevented; buffer allows extra; idle-covered early return. |
| **HL-004** | High | Honest naming: adapter `sweepResidualHype` / `pendingLockedNestShare`; vault `claimResidualHype` / `pendingResidualHype` / `settleResidualHype`. NatSpec: no invented HYPE Spring. Mocks + tests + keeper comments updated. |
| **HL-005** | High | `MockVotingEscrow.liveDettachReset` **default true** (26w). Opt-out via `setLiveDettachReset(false)` still available; test covers both. |
| **HL-006** | Medium (design) | Unchanged design; documented in WITHDRAW_WINDOWS + checklist (idle + 26w worst case). |
| **HL-007** | Medium | `depositsEnabled` default **false**; owner `setDepositsEnabled`. Checklist mandates idle params before enable. |
| **HL-008** | High | `setHevAdapter` rejects `address(0)`. `dettachForLiquidity` requires adapter when gap>0; clears `inHev` / sets `unlockEligibleAt` **only after** successful `withdrawVeNFT`. Regression tests. |
| **HL-009** | Medium | `setMinIdleNest` / `setIdleDepositBps` → `onlyOwner`. Guardian pause-only. Test: guardian cannot set idle. |
| HL-010…016 | — | Not in this fix batch (gas pagination, unlock week align, keeper rewrite, etc.). Noted as remaining gaps. |

## Files touched

- `src/NestVault.sol`, `src/HevAdapter.sol`, `src/HNest.sol`
- `src/interfaces/IHevAdapter.sol`, `INestVaultHype.sol`, (+ light NatSpec on related interfaces)
- `test/NestVault.t.sol`, `test/mocks/MockVotingEscrow.sol`, `test/mocks/MockHevAdapter.sol`
- `keeper/keeper.ts` (comments)
- `docs/DEPLOYMENT_CHECKLIST.md`, `docs/AUDIT_FIXES_v1.md`

## Remaining gaps

- Real Nest HEV e2e fork: deposit → queue → dettach → 26w → fulfill (incomplete; `HevFork.t.sol` smoke only)
- Voter vote-delay / full dettach lock-window coverage
- VirtualRewarder live impl source (Sourcify 404)
- Keeper script still harvest-centric; needs queue / dettach / topUp runbook rewrite (HL-016)
- HL-010 O(n) harvest/process gas at scale
