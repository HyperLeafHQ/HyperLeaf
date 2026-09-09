# Hyperleaf hNEST / NestVault — 预审计交接包

**日期:** 2026-09-06 (Asia/Shanghai UTC+8)  
**品牌:** Hyperleaf（GitHub org: [HyperLeafHQ](https://github.com/HyperLeafHQ/HyperLeaf)）  
**代码命名:** 合约/代币仍可能为 `hNEST` / `NestVault`（仅命名；协议品牌为 Hyperleaf）  
**本地路径:** `/workspace/hyperevm-lst/hnest`  
**官方仓库:** https://github.com/HyperLeafHQ/HyperLeaf  

> **同步状态:** 本地 box 工作区 **尚未** 配置 `origin` 指向 HyperLeafHQ，且 `master` 尚无提交。审计请以本交接包 + 本地树为准；与 GitHub 远程是否一致需 parent/推送方确认，**勿假设已同步**。

**本包性质:** 事实与范围整理，**非**审计结论；未发明 finding。未部署。

相关文档指针:
- `docs/HEV_ABI_PROBE.md` — mainnet ABI / selector 探针
- `docs/FORK_SIM.md` — createLockFor 标志 + dettach 重置
- `docs/WITHDRAW_WINDOWS.md` — idle buffer / 提现窗口设计
- `docs/DIFF_SUMMARY.md` — 相对朴素 Solidly 假设的差异

---

## 1. Scope（审计范围）

| 组件 | 路径 | 说明 |
|------|------|------|
| NestVault | `src/NestVault.sol` | 核心金库：deposit → createLockFor+HEV attach → mint hNEST；提现队列；idle buffer；pause/guardian |
| HNest | `src/HNest.sol` | LST 收据 ERC20+Permit；P2P 转账 settle HYPE debt hooks |
| HevAdapter | `src/HevAdapter.sol` | 生产向适配器：attach/dettach via Voter；pending=NEST share；claimHype=余额扫出 |
| Interfaces | `src/interfaces/*` | `IVotingEscrow`, `IVoter`, `IHevAdapter`, `IHevStrategy`, `IVirtualRewarder`, … |
| Config | `src/config/HyperEVMAddresses.sol` | HyperEVM mainnet Nest/HEV 常量 |
| Mocks（单测/testnet） | `test/mocks/*`, `DeployMock.s.sol` | MockVotingEscrow / MockHevAdapter / MockERC20 — **非** live Nest |
| Mainnet ABI 快照 | `abi/mainnet/*.abi.json` | 探针确认的 Voter/veNEST/HEV/VR/… |
| Keeper 草稿 | `keeper/keeper.ts` | 运维脚本草稿（信任边界见 §6） |

**Pause / guardian 模型（已实现）:**
- `guardian` 或 `owner` → `pause()`：阻断 `deposit` + `requestWithdraw`
- **仅** `owner` → `unpause()`（guardian/keeper 不可）
- keeper **不能** pause/unpause
- `setGuardian`：`onlyOwner`；`address(0)` 关闭 guardian
- pause 期间 keeper 仍可 harvest / process / dettach / topUpIdle

**明确不在本包声称“已就绪”的:**
- 用户侧液态 **HYPE / MEGAHYPE** claim（ABI 未找到）
- 端到端 fork：deposit → queue → dettach → 26w → fulfill（真实 NEST）
- Production multisig guardian/owner/keeper

---

## 2. Addresses（务必区分 mock vs live）

### 2.1 Testnet-998 — **MOCK**（`deployments/testnet-998.json`）

| 项 | 值 | 标签 |
|----|-----|------|
| Network | HyperEVM testnet, chainId **998** | MOCK |
| RPC | `https://rpc.hyperliquid-testnet.xyz/evm` | |
| NestVault | `0x6f8d22C85e505eCA309635EA552f5067C026A2A9` | MOCK |
| HNest | `0xe86961EAF3CD4ED87497641fF32E55875aB7189f` | MOCK |
| HevAdapter / MockHevAdapter | `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` | MOCK |
| NEST (mock ERC20) | `0x4C862bC0922556e1bF02561bcf6Ff25e43826D5C` | MOCK |
| HYPE (mock ERC20) | `0xc89273ACB22a4e1df81A396FE0Bf6eD6E2CA6fD2` | MOCK |
| MockVotingEscrow | `0x2101621F51D7E05518D6680C62d04Ad47bC4e05D` | MOCK |
| deployer/owner/guardian/keeper/feeRecipient | 均为 `0xc321DD8826a30D8a6D973821a3dB7b8090955887` | **EOA drill only** |

> `guardianNote`: 本 drill guardian=部署者 EOA。**生产 guardian 必须改为用户/团队 multisig。**  
> 非 mainnet，非真实 Nest HEV。

### 2.2 HyperEVM mainnet (999) — **LIVE Nest 协议地址**（`HyperEVMAddresses` + probe）

| Role | Address | 标签 |
|------|---------|------|
| NEST | `0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035` | LIVE |
| veNEST | `0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074` | LIVE |
| Voter | `0x566bdc5444fd5fe5d93ec379Bd66eC861ddbA901` | LIVE |
| ManagedNFTManager | `0x843d31e601b38F7207864457f0fB38E14441E792` | LIVE |
| HEV strategy | `0x96F7b8BA7580d3E510B0Fb3F0E135a743d8eb17a` | LIVE（managedTokenId=**1**） |
| VirtualRewarder | `0x148405ab9F58AC790CC6cA518077deD1E6E04829` | LIVE（impl 源码未 Sourcify） |
| VeNestDistributor | `0x22350F14c6ee70992f1bbc7498e4C291B8B7682f` | LIVE（admin airdrop，非用户 claim） |

> **本仓库尚未部署** mainnet NestVault / HNest / HevAdapter。上表为上游 Nest 基础设施，供 adapter 接线与 fork 探针使用。

---

## 3. Confirmed mainnet ABIs（2026-09-03 探针）

| Sig | Selector | Where | 用途 |
|-----|----------|-------|------|
| `attachToManagedNFT(uint256,uint256)` | `0xca82240d` | Voter | 入口 attach |
| `dettachFromManagedNFT(uint256)` | `0x12dd7200` | Voter | 出口 dettach（双 t 拼写） |
| `createLockFor(uint256,uint256,address,bool,bool,uint256)` | `0x42c15c87` | veNEST | 铸造+可选原子 attach |
| `getNftState(uint256)` | — | veNEST | LockedBalance + isAttached |

**Claim 语义（诚实边界）:**
- Pending = `HEV.getLockedRewardsBalance(tokenId)` ≡ `VR.calculateAvailableRewardsAmount` → **NEST share**（非液态 HYPE）
- `VR.harvest` = strategy-only（非策略 → `AccessDenied`）
- **无** 公开用户 HYPE / MEGAHYPE claim ABI；`HevAdapter.claimHype` 仅扫 adapter 上残余 HYPE ERC20（通常为 0）
- 名称 `pendingHype` / `claimHype` 为 vault ABI 稳定保留；语义上 pending 是 NEST share

Artifact: `abi/mainnet/{Voter,VotingEscrow,ManagedNFTManager,HEV_strategy,VirtualRewarder,VeNestDistributor}.abi.json`

---

## 4. Security decisions（已拍板设计，非 finding）

1. **Guardian pause:** 阻断 deposit + requestWithdraw；**仅 owner unpause**（防 hot-wallet/keeper 劫持恢复）。
2. **Idle buffer（提现偿付）:** 见 `docs/WITHDRAW_WINDOWS.md`  
   - 主路径：`idleDepositBps` 存款 skim 留在 vault  
   - 辅路径：keeper `topUpIdle`  
   - 绝对地板：`minIdleNest`；fulfill 只花 `balance - minIdleNest`  
   - `requestWithdraw` **不** dettach（避免立刻触发 26w 重置）
3. **createLockFor 标志（NestVault.deposit）:**
   - `to_ = address(this)`（vault 持有 NFT）
   - `shouldBoosted_ = false`
   - `withPermanentLock_ = false`
   - `managedTokenIdForAttach_ = 1`（HEV 原子 attach）
4. Adapter `depositVeNFT`：若已 `isAttached` 则跳过 attach（幂等）。

---

## 5. Test evidence

### 5.1 Unit — `forge test` → **25/25 PASS**（2026-09-06）

默认 profile **排除** `test/HevFork.t.sol`（公网 RPC 限流）。

关键用例（`test/NestVault.t.sol`）:
- 存取/份额: `test_DepositMintsOneToOne`, `test_DepositCap`, `test_RecordCompoundRaisesSharePrice`, `test_WithdrawQueueAfterUnlock`
- Pause/guardian: `test_PauseBlocksDeposit`, `test_PauseBlocksRequestWithdraw`, `test_GuardianCanPause`, `test_GuardianCannotUnpause`, `test_OnlyOwnerUnpauses`, `test_KeeperCannotPause`, `test_KeeperCannotUnpause`, `test_SetGuardianAllowsZeroToDisable`
- Idle buffer: `test_IdleDepositSkimFundsBuffer`, `test_WithdrawFulfilledFromIdleSurplus`, `test_IdleShortfallRevertsWhenMinBlocksHead`, `test_TopUpIdleThenFulfill`, `test_IdleDepositBpsCap`, `test_GuardianCanSetIdleParams`
- Dettach 策略: `test_RequestWithdrawDoesNotDettach`, `test_DettachTooEarlyReverts`, `test_LiveDettachResetsLockTo26w`
- HYPE 记账 stubs: `test_HarvestClaimsHypeNoVote`, `test_TransferSettlesHype`
- 常量: `test_AddressesConstants`

### 5.2 Testnet-998 pause drill + 存款 smoke（已记录于 deployments）

来源: `deployments/testnet-998.json` → `smoke`（2026-09-03 +08）:
1. approve → **deposit1**（hNEST 1e18）
2. **pause** → `depositWhilePaused` eth_call → `EnforcedPause`（无状态变更）
3. **unpause** → **deposit2** → final hNEST / totalNestLocked = **2e18**；`pausedAfterDrill=false`
4. 二次 verify pause/unpause txs 亦在 json 中

Mock NEST 经 `mintNEST` 铸给部署者后存款（非真实 NEST）。Guardian=EOA（见 §2.1 / §6）。

### 5.3 Fork sim 摘要（`docs/FORK_SIM.md`）

- RPC: `https://rpc.hyperliquid.xyz/evm`（999）；**无 broadcast**
- `createLockFor` + atomic attach fork 测试 PASS（tokenId 示例 4430，`isAttached=true`）
- 关键发现: `onDettachFromManagedNFT` 将 lock end 重置为 **now+26w**
- Attached 时 `getNftState` amount/end = 0
- HEV `detachmentLockDuration` = 4 days (HEV fact)
- NestVault `DETACHMENT_LOCK_DURATION` in this source = **8 days** (NEST reward cycle is 7 days). The already-deployed live vault is immutable and still has 4 days.
- Claim: 仅 NEST share pending；无用户 HYPE claim

---

## 6. Known gaps / 审计优先攻击面（优先审查清单，非已证实漏洞）

1. **HYPE claim 未知** — 无用户液态 HYPE/MEGAHYPE 路径；`claimHype` 名实不符风险 / 产品诚实披露  
2. **dettach → 26w lock reset** — 与“原 createLock 到期解锁”直觉相反；队列偿付依赖 idle 或接受长延迟  
3. **Attached 零 amount/end** — 误读 `getNftState` 会导致错误 unlock/sizing；vault 用 `nestPrincipal` / `unlockEligibleAt`  
4. **Idle donation / share price** — 直接转 NEST 进 vault、`topUpIdle`、skim 与 `totalNestLocked` 会计边界；捐赠是否抬价/可抽  
5. **Vote / dettach 窗口** — Voter vote-delay、dettachLockWindow；fork 覆盖仍不完整  
6. **Keeper 信任** — harvest / dettachForLiquidity / process / recordCompound / topUpIdle；错误或恶意 dettach 可点燃 26w 时钟  
7. **Guardian=EOA on testnet** — 生产必须 multisig；owner/keeper 同理  
8. **Mock vs live 行为差** — 默认 MockVotingEscrow dettach **恢复**旧 end；`liveDettachReset=true` 才模拟 mainnet（单测已有 `test_LiveDettachResetsLockTo26w`）  
9. **VR impl 源码未验证** — ABI 经 Nest SingelToken + eth_call 对齐，但 live impl `0x7ea6…e8cb` Sourcify 404  
10. **HyperEVM 3M block gas** — NestVault+HNest 需分拆部署（已处理）；部署脚本 OOGs 历史见 deployments note

---

## 7. How to run

```bash
cd /workspace/hyperevm-lst/hnest

# 单元测试（25 tests；排除 HevFork）
forge test

# Fork 探针（公网 RPC 易 -32005；可选私有 RPC）
export HYPEREVM_RPC_URL=https://rpc.hyperliquid.xyz/evm   # 或自备
FOUNDRY_PROFILE=fork forge test --match-contract HevForkTest

# 配置见 foundry.toml / .env.example
# [profile.default] no_match_path = test/HevFork.t.sol
# [profile.fork]    match_path   = test/HevFork.t.sol
```

**RPC:**
- Mainnet HyperEVM: `https://rpc.hyperliquid.xyz/evm` (999)
- Testnet: `https://rpc.hyperliquid-testnet.xyz/evm` (998)

**不要**对 mainnet 广播本包范围内的部署/真实 NEST 操作（交接包只读证据）。

---

## 8. 文件索引（给审计 bot）

```
src/NestVault.sol
src/HNest.sol
src/HevAdapter.sol
src/interfaces/
src/config/HyperEVMAddresses.sol
test/NestVault.t.sol
test/HevFork.t.sol          # FOUNDRY_PROFILE=fork
test/mocks/
abi/mainnet/
deployments/testnet-998.json
docs/HEV_ABI_PROBE.md
docs/FORK_SIM.md
docs/WITHDRAW_WINDOWS.md
docs/DIFF_SUMMARY.md
docs/AUDIT_HANDOFF.md      # 本文件
```
