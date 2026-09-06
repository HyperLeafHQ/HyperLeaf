# DIFF_SUMMARY — 相对朴素 Solidly 假设

**品牌:** Hyperleaf（代码名 hNEST / NestVault）  
**对照:** 经典 Solidly/Velodrome 风格 ve(3,3) 集成假设  
**目的:** 避免审计/实现按 Solidly 默认心智误读 Nest HyperEVM

---

| 朴素 Solidly 假设 | Nest / Hyperleaf 实际 |
|-------------------|------------------------|
| `createLock(amount, duration)` | **缺失**。用 `createLockFor(amount, duration, to, shouldBoosted, withPermanentLock, managedTokenIdForAttach)` |
| `locked(tokenId)` → (amount, end) | 用 `getNftState` / `nftStates`；**attached 时 amount=0 且 end=0** |
| `voter.attach` / `detach` 命名 | `attachToManagedNFT` / `dettachFromManagedNFT`（**双 t** `dettach`） |
| `lastVoted(tokenId)` | `lastVotedTimestamps(tokenId)` |
| 锁到期即可 `withdraw` | Attached 时不可撤；dettach 后 live `onDettach` 把 end 重置为 **≈now+26w**（非原到期） |
| 用户 `getReward` / `earned` 领激励 | VR **无** `getReward(address)` / `earned`；`harvest` 仅 strategy；pending = **NEST share**（`getLockedRewardsBalance`） |
| 液态 HYPE 用户 claim | **未找到**公开 ABI；MEGAHYPE 未上线；adapter `claimHype` 仅扫 stray ERC20 |
| Redeem 立刻 dettach 解锁 | **禁止**作为默认路径：会点燃新 26w；改用 **idle NEST buffer** + 按需 `dettachForLiquidity` |
| Boost / permanent lock 默认开 | Vault 显式 `shouldBoosted_=false`, `withPermanentLock_=false` |
| 单测 mock ≈ mainnet | 默认 Mock dettach **恢复旧 end**；需 `liveDettachReset` 才仿真 26w 重置 |

设计落点: `docs/WITHDRAW_WINDOWS.md`, `docs/FORK_SIM.md`, `docs/HEV_ABI_PROBE.md`, `docs/AUDIT_HANDOFF.md`。
