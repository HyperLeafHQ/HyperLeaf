# NestVault / hNEST — Mainnet Deployment Checklist

**Status:** Mandatory before opening deposits. Internal audit HL-001 / HL-007.  
**Updated:** 2026-09-06 (Asia/Shanghai) — roles + idle values confirmed by operator.

## Confirmed production roles (four-way split)

| Role | Address | Notes |
|------|---------|--------|
| **Owner** | `0x24458f0bC44C4607172d1151Cd938012Be33156e` | User-controlled EOA. Ownable2Step: deploy → `transferOwnership` → Owner `acceptOwnership`. |
| **Guardian** | `0x12dF4528E7Cc3db07A509c966c6405b69A25Ef2e` | User's **other** EOA (**≠ Owner**). **Pause only** (cannot unpause / idle / adapter / depositsEnabled). |
| **Keeper** | `0xc321DD8826a30D8a6D973821a3dB7b8090955887` | Hyperleaf hot wallet. harvest / process / dettachForLiquidity / topUpIdle only. **Never Owner or Guardian.** |
| **feeRecipient** | `0x76c8c4586F0a3d335CF7192eBbB4FE6Ed5Af3804` | Protocol fee sink (performance fee cut). Separate from Keeper. |
| **Deployer** | same hot wallet as Keeper for deploy txs only | Deploy + initial config, then hand Owner to user. **NEVER leave deployer as Owner/Guardian.** |

Testnet may collapse roles for drills. **Copying testnet role collapse to mainnet is forbidden.**

## Confirmed idle parameters (HL-007)

| Param | Value | Meaning |
|-------|-------|---------|
| `idleDepositBps` | **100** | 1% of each deposit stays liquid idle; 99% locks into veNEST/HEV. Example: deposit 100 NEST → 1 idle + 99 HEV. |
| `minIdleNest` | **50 NEST** (`50e18`) | Absolute floor; queue fulfillments only spend `balance - minIdleNest`. |

**Product assumption:** most exits via secondary market (sell hNEST); protocol redeem is minority backstop → lean idle is intentional.

## Confirmed topUpIdle budget

| Item | Value | Notes |
|------|-------|--------|
| Initial `topUpIdle` budget | **50 NEST** | Funded from Hyperleaf keeper/hot wallet before `setMinIdleNest(50e18)`. |
| Purpose | Seed idle so floor can be set | Required because `setMinIdleNest` reverts if vault NEST balance &lt; new floor. |
| Ongoing | Opportunistic | Further topUps only if queue gap / floor pressure; not a standing weekly mint. |

Source of funds: hot wallet `0xc321DD8826a30D8a6D973821a3dB7b8090955887` (already holds mainnet NEST for ops).

**Set order (important):**
1. Deploy with `depositsEnabled = false`.
2. Configure roles (Guardian / Keeper / feeRecipient) while deployer still Owner, **or** after user `acceptOwnership`.
3. `setIdleDepositBps(100)`.
4. `topUpIdle` ≥ 50 NEST (cannot `setMinIdleNest(50e18)` if vault NEST balance &lt; 50).
5. `setMinIdleNest(50e18)`.
6. Owner `acceptOwnership` if not done.
7. Smoke checks → only then Owner `setDepositsEnabled(true)`.

## Pre-deposit configuration checklist

1. [ ] Ownable2Step handoff to Owner `0x24458f0b…156e` complete (`acceptOwnership`).
2. [ ] `setGuardian` → `0x12dF4528…Ef2e`.
3. [ ] `setKeeper` → `0xc321DD88…5887`.
4. [ ] `setFeeRecipient` → `0x76c8c458…3804`.
5. [ ] `setHevAdapter` → production HevAdapter (**rejects address(0)**).
6. [ ] `setIdleDepositBps(100)` + `topUpIdle` ≥ 50 + `setMinIdleNest(50e18)`.
7. [ ] Optional: `setDettachBufferBps` documented.
8. [ ] Confirm `recordCompound` disabled (`CompoundDisabled`).
9. [ ] Confirm `depositsEnabled == false` until step 10.
10. [ ] Owner `setDepositsEnabled(true)` only after 1–9 + smoke.

## Compound policy (HL-002)

- `recordCompound` **always reverts** (`CompoundDisabled`).
- Do not market liquid Nest HYPE / HYPE Spring / MEGAHYPE until claim ABI is wired.

## Security gates already in code

| Gate | Behavior |
|------|----------|
| HL-002 | `recordCompound` → `CompoundDisabled()` |
| HL-003 | `dettachForLiquidity` caps principal to queue gap + `dettachBufferBps` |
| HL-008 | `setHevAdapter(0)` reverts; dettach clears `inHev` only after `withdrawVeNFT` |
| HL-009 | Idle params `onlyOwner`; guardian pause-only |
| HL-007 | `depositsEnabled` default `false` |

## Post-deploy monitors

- `DettachForLiquidity`, `HevAdapterUpdated`, `Paused` / `Unpaused`, `DepositsEnabledUpdated`
- `pendingWithdrawNest` vs `availableIdleNest`
- Role addresses remain the four-way split above
