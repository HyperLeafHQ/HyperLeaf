# NestVault / veNEST fork simulation (read-only)

**Date:** 2026-09-03 (Asia/Shanghai UTC+8)  
**RPC:** `https://rpc.hyperliquid.xyz/evm` (chainId 999)  
**Mode:** `cast call` + Sourcify source review + optional `forge test --match-contract HevForkTest`  
**No broadcast. No NEST/HYPE spent.**

---

## 1. createLockFor flag choices (NestVault.deposit)

```solidity
veNEST.createLockFor(
    nestAmount,
    MAX_LOCK_DURATION,              // 26 weeks (= Nest MAX_LOCK_TIME)
    address(this),                  // to_ = vault
    false,                          // shouldBoosted_
    false,                          // withPermanentLock_
    HyperEVMAddresses.HEV_MANAGED_TOKEN_ID  // 1 — atomic attach to HEV
);
```

| Flag | Value | Why |
|------|-------|-----|
| `to_` | `address(this)` | Vault owns veNFT; withdraw/approve/adapter path stays in vault |
| `shouldBoosted_` | `false` | Boost (`veBoost`) not productized here; avoid unverified fee/boost routes |
| `withPermanentLock_` | `false` | Preserve timed-lock + withdraw-queue product intent (see §3 caveat) |
| `managedTokenIdForAttach_` | `1` | HEV managed NFT; VE calls `Voter.attachToManagedNFT` internally (`_revertIfNotVotingEscrowOrApprovedOrOwner` allows VE) |

`HevAdapter.depositVeNFT` then records deposit and **skips** `attachToManagedNFT` when `getNftState(tokenId).isAttached` is already true (idempotent vs atomic create).

---

## 2. eth_call / cast results (this pass)

| Probe | Result |
|-------|--------|
| `createLock(uint256,uint256)` | execution reverted (selector **missing**) |
| `createLockFor(..., managedId=0)` no NEST | revert `ERC20: insufficient allowance` → selector **exists** (`0x42c15c87`) |
| `getNftState(100)` | locked=(0,0,false), isAttached=**true** (amount+end zeroed while attached) |
| `HEV.getLockedRewardsBalance(100)` | `~3.53e22` NEST share |
| `VR.calculateAvailableRewardsAmount(100)` | equal to HEV balance |
| `HEV.managedTokenId()` | `1` |
| `HEV.detachmentLockDuration()` | `345600` (4 days) — HEV fact. NestVault dettach matches 4d. Circulation gate is separate (8d / epoch). |

Forge fork tests live under `FOUNDRY_PROFILE=fork` (`test/HevFork.t.sol`); default `forge test` excludes them because public RPC rate-limits (`-32005`) flake storage fetches. Prefer `cast` + profiled fork when needed.

### Confirmed forge fork (no broadcast)

`testFork_CreateLockForAtomicAttach` with `deal(NEST)` + `approve` + contract `to_`:

- **PASS** — minted `tokenId = 4430`, `getNftState.isAttached == true`, `ownerOf == vaultLike`
- Flags used: `shouldBoosted_=false`, `withPermanentLock_=false`, `managedTokenIdForAttach_=1`

---

## 3. Critical Sourcify finding — post-dettach lock reset

From `VotingEscrowUpgradeableV2.onDettachFromManagedNFT`:

```solidity
_updateNftLocked(tokenId_, LockedBalance(amount, LibVotingEscrowUtils.maxUnlockTimestamp(), false));
```

`maxUnlockTimestamp()` = `roundToWeek(block.timestamp + MAX_LOCK_TIME)` with `MAX_LOCK_TIME = 15724800` (**26 weeks**).

Implications for NestVault withdraw queue:

1. While **attached**, user `LockedBalance` is `(0, 0, false)` — cannot `withdraw` until dettach.
2. After **dettach**, lock end is reset to **now+26w**, not the original createLock duration.
3. Combined with HEV `detachmentLockDuration` (4d) + Voter vote-delay/window, liquid NEST for the withdraw queue is **not** “original lock end → unlock”.
4. Unit `MockVotingEscrow` restores the **prior** `end` on `mockDettach` so timed unlock tests stay deterministic; **live** behavior differs (document as mainnet blocker).

---

## 4. Atomic attach auth path

`Voter.attachToManagedNFT` gate: `_revertIfNotVotingEscrowOrApprovedOrOwner`.  
`createLockFor` → VE calls Voter → **OK** for contract `to_` without pre-approve.  
Fallback: vault `approve` adapter → `HevAdapter.depositVeNFT` → `attachToManagedNFT` if not already attached.

---

## 5. Claim path (unchanged honesty)

- `VR.harvest` — strategy-only (`AccessDenied` otherwise).
- Pending share — `HEV.getLockedRewardsBalance` / `VR.calculateAvailableRewardsAmount` (**NEST**).
- No public HYPE / MEGAHYPE user claim ABI found; `claimHype` remains adapter balance sweep only.
