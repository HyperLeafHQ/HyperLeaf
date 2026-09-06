# NestVault / hNEST — Mainnet Deployment Checklist

**Status:** Mandatory before opening deposits. Internal audit HL-001 / HL-007.

## Confirmed production roles (do not collapse)

| Role | Who | Notes |
|------|-----|--------|
| **Owner** | **User EOA** (operator / protocol owner) | Ownable2Step: deploy with temp key → `transferOwnership` → user `acceptOwnership`. **Never leave Hyperleaf deployer as Owner.** |
| **Guardian** | **User's OTHER EOA** (≠ Owner) | **Pause only.** Cannot unpause, cannot change idle / dettach buffer / fees / adapter / depositsEnabled. |
| **Keeper** | Hyperleaf hot wallet `0xc321…5887` | harvest / process / dettachForLiquidity / topUpIdle only. **Never Owner or Guardian.** |
| **feeRecipient** | Separate address (treasury / fee sink) | ≠ Owner, ≠ Guardian, ≠ Keeper preferred. |
| **Deployer** | CI / deploy key | Deploy only. Transfer Owner to user via Ownable2Step, then stop using for privileged ops. **NEVER set deployer as Owner or Guardian on mainnet.** |

Testnet may use one EOA for drills. **Copying testnet role collapse to mainnet is forbidden.**

## Pre-deposit configuration (HL-007)

1. Complete Ownable2Step ownership handoff to **user Owner**.
2. `setGuardian` → user's other EOA.
3. `setKeeper` → `0xc321…5887` (or rotated Hyperleaf hot wallet documented in runbook).
4. `setFeeRecipient` → separate fee address.
5. `setHevAdapter` → production HevAdapter (**rejects address(0)**).
6. Set idle before open:
   - `setIdleDepositBps` (owner) — non-zero skim recommended for queue liquidity
   - `setMinIdleNest` (owner) — floor for fulfillments
   - Document keeper `topUpIdle` funding source
7. Optional: `setDettachBufferBps` (owner) — overshoot allowance when capping dettach principal to queue gap.
8. Confirm `recordCompound` is disabled (`CompoundDisabled`) — no unbacked share-price inflate.
9. Confirm `depositsEnabled == false` until step 10.
10. Owner calls `setDepositsEnabled(true)` only after steps 1–9 and smoke checks.

## Compound policy (HL-002)

- `recordCompound` **always reverts** (`CompoundDisabled`).
- Share-price uplift from locked NEST compound must not be recorded without verifiable on-chain assets.
- Future re-enable requires a new design (owner+timelock + readable increase), not flipping a flag in this MVP.

## Security gates already in code

| Gate | Behavior |
|------|----------|
| HL-002 | `recordCompound` → `CompoundDisabled()` |
| HL-003 | `dettachForLiquidity` caps cumulative `nestPrincipal` to queue gap + `dettachBufferBps` |
| HL-008 | `setHevAdapter(0)` reverts; dettach clears `inHev` only after `withdrawVeNFT` |
| HL-009 | Idle params `onlyOwner`; guardian pause-only |
| HL-007 | `depositsEnabled` default `false` |

## Do not claim

- Do **not** market liquid Nest HYPE / “HYPE Spring” / MEGAHYPE user claims.
- Adapter `sweepResidualHype` = stray ERC20 sweep (usually 0).
- Adapter `pendingLockedNestShare` = NEST-denominated locked reward share.

## Post-deploy monitors

- `DettachForLiquidity`, `HevAdapterUpdated`, `Paused` / `Unpaused`, `DepositsEnabledUpdated`
- `pendingWithdrawNest` vs `availableIdleNest`
- Role addresses remain split as in the table above
