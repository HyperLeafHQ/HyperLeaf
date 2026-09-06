# Hyperleaf hNEST / NestVault — 内部审查 v1

| 项 | 内容 |
|----|------|
| 日期 | 2026-09-06（Asia/Shanghai，UTC+8） |
| 性质 | **内部审查**（非正式外部审计报告） |
| 审查人角色 | 独立内审执行器（对照 handoff 线索，结论自源码/测试复现） |
| 本地路径 | `/workspace/hyperevm-lst/hnest` |
| 测网 | HyperEVM testnet-998 **MOCK**（`deployments/testnet-998.json`） |
| 主网合约 | 本仓库 **尚未** 部署 NestVault/HNest/HevAdapter；仅接线上游 Nest 地址 |

---

## 1. 范围

**已审：**

| 组件 | 路径 |
|------|------|
| NestVault | `src/NestVault.sol` |
| HNest | `src/HNest.sol` |
| HevAdapter | `src/HevAdapter.sol` |
| 接口 / 地址常量 | `src/interfaces/*`, `src/config/HyperEVMAddresses.sol` |
| 单测 + mocks | `test/NestVault.t.sol`, `test/mocks/*` |
| 测网部署记录 | `deployments/testnet-998.json` |
| 事实文档（线索，非结论） | `docs/AUDIT_HANDOFF.md`, `DIFF_SUMMARY.md`, `WITHDRAW_WINDOWS.md`, `FORK_SIM.md`, `HEV_ABI_PROBE.md` |
| Keeper 草稿 | `keeper/keeper.ts`（运维面） |

**未声称已审 / 未完成：**

- 真实 NEST 端到端 fork：`deposit → queue → dettach → 26w → fulfill`
- Voter vote-delay / `dettachLockWindow` 全覆盖
- VirtualRewarder live impl 源码（Sourcify 404；ABI 经探针对齐）
- 外部专业审计、形式化验证、经济攻击完整博弈模型

---

## 2. 测试证据

```text
$ forge test   # profile.default 排除 HevFork.t.sol
Suite: NestVaultTest — 25 passed; 0 failed; 0 skipped
```

**本机复跑：** 2026-09-06，`25/25 PASS`（约 13ms）。

**额外内审复现（未合入仓库，跑完即删）：**

1. `recordCompound(900 ether)` 后用户按抬高后负债 `requestWithdraw` → 队列挂账 **1000 NEST**，金库存量仅 NFT 内 **100 NEST** → **资不抵债路径成立**。
2. `setHevAdapter(address(0))` 后 `dettachForLiquidity` → 金库 `inHev=false` 且写入 `unlockEligibleAt`，链上 NFT **仍 attached** → 后续无法再 dettach（`NotInHev`），本金路径卡住。

测网 smoke（json 记录）：approve → deposit → pause 挡存 → unpause → 再存；`finalHNestBalance=2e18`；**非** 真实 Nest HEV。

---

## 3. 必查项结论（摘要）

| 必查项 | 结论 | 阻塞主网？ |
|--------|------|------------|
| Guardian pause（停存+停赎）/ 仅 owner unpause | **符合设计**：guardian/owner 可 pause；仅 owner unpause；keeper 不能 pause/unpause；单测+测网 smoke 覆盖 | 否（机制本身） |
| Keeper 权限 | harvest / process / dettach / topUp / **无证明的 recordCompound**；pause 期间仍可运维 | **是**（见 HL-002/003） |
| Idle buffer 会计 | skim + `minIdleNest` 地板 + fulfill 只花盈余；`topUpIdle` 不改份额；直接捐赠 NEST **不**抬 `sharePrice`（有利于偿付） | 参数未配置时 **是**（HL-007） |
| dettach → 26w | 金库用 `unlockEligibleAt=now+26w` 对齐 live `onDettach`；`requestWithdraw` **不** dettach（正确） | 设计可接受；须披露（HL-006） |
| HYPE claim 名实 | Adapter `claimHype`=扫残余 ERC20；`pendingHype(tokenId)`=**NEST share**；Vault MasterChef 路径依赖真实 HYPE 入账（主网通常为 0） | **宣传 HYPE 收益则是**（HL-004） |
| 捐赠 / 份额通胀 | 直接转 NEST 不抬价；**`recordCompound` 无资产可抬价并制造超额赎回负债** | **是**（HL-002） |
| Mock vs live | 默认 Mock dettach **恢复旧 end**；HYPE 单测靠 `seedReward`，与生产 adapter 行为不同 | **是**（覆盖缺口，HL-005） |
| 测网 guardian=owner=keeper 同 EOA | 演练可接受；**原样搬主网不可接受** | **是**（HL-001） |

---

## 4. 发现明细

### HL-001 — 测网角色合一；主网必须拆分多签

- **级别:** Critical（部署/密钥，非逻辑漏洞）
- **阻塞主网:** **是**
- **根因:** `deployments/testnet-998.json` 中 `owner` / `guardian` / `keeper` / `feeRecipient` / `deployer` 均为同一 EOA `0xc321…5887`。代码**允许**该配置；pause 模型「仅 owner unpause」在同钥时形同虚设（劫持即可自 pause 自 unpause）。
- **要求:** 主网部署清单强制：owner 多签 ≠ guardian 多签 ≠ keeper 热钱包；feeRecipient 独立；Ownable2Step 完成移交后再开放存款。测网同 EOA **不**阻塞继续测网，**阻塞**生产开放。

### HL-002 — `recordCompound` 无资产证明即可抬高负债（已复现）

- **级别:** Critical
- **阻塞主网:** **是**（keeper 为热钱包或单人时无条件阻塞；即便多签亦须改设计或强流程）
- **根因:** `NestVault.recordCompound` 仅 `totalNestLocked += addedNest`，不校验 ve/HEV 可读增量、不转入 NEST。份额价上升后，赎回 `nestAmount = hNest * totalNestLocked / supply` 可大于真实可兑付 NEST → 挤兑/穿仓。
- **复现:** 存 100 → `recordCompound(900)` → 全额赎回队列负债 1000，金库仅 100 锁定。
- **要求（主网前至少一项）:** 删除或改为 owner+timelock；或强制 `addedNest` 来自可验证链上读数且有上限/双人；上线前禁用该入口。

### HL-003 — Keeper `dettachForLiquidity` 可点燃 26w 并过度 dettach

- **级别:** High
- **阻塞主网:** **是**（keeper=EOA/无监控时）；多签+runbook+告警后可降为运维风险
- **根因:** 队列缺口时 keeper 传入任意已 attach 且过 4d 的 `tokenIds`；合约**不**按缺口大小限制 dettach 本金。一次误操作/恶意可把大量仓位重置为 ~now+26w。有「idle 已覆盖则 early return」保护，但缺口很小时仍可拆大仓。
- **要求:** 监控 `DettachForLiquidity`；runbook 规定最小拆仓策略；考虑链上按缺口累计本金上限。

### HL-004 — `claimHype` / `pendingHype` 名实不符（产品诚实）

- **级别:** High（披露/集成误导；非直接盗款）
- **阻塞主网:** **是**——若对外称「可领液态 HYPE / HYPE Spring」；**否**——若产品明确仅为 NEST 锁仓 LST + 份额增值，并改名/加警告
- **根因:** 探针确认无用户 HYPE/MEGAHYPE claim ABI；生产 `HevAdapter.claimHype` 只转发 adapter 上残余 HYPE（通常 0）；adapter `pendingHype(tokenId)` 实为 `getLockedRewardsBalance`（**NEST share**）。Vault 侧 MasterChef 会计在无 HYPE 入账时恒为 0。单测 `seedReward` 制造了「能领 HYPE」的假阳性。
- **要求:** UI/文档/NatSpec 对齐；禁止暗示已上线液态 HYPE 收益，直至 Nest 公布真实 ABI 并接线。

### HL-005 — Mock 与 live 行为差导致测试假信心

- **级别:** High（覆盖）
- **阻塞主网:** **是**（在未完成真实路径演练前，不建议放大 TVL）
- **根因:**
  1. 默认 `MockVotingEscrow` dettach **恢复旧 end**；仅 `liveDettachReset=true` 才模拟 26w（有单测，但多数路径仍走默认）。
  2. `MockHevAdapter.claimHype` 按 token 发 HYPE；生产 adapter 扫余额且无 VR 用户 claim。
  3. 缺真实 NEST 全流程 fork。
- **要求:** 归档 e2e fork 或主网小额 rehearsal；默认 mock 更贴近 live 或 CI 强制跑 `liveDettachReset` 套件。

### HL-006 — 偿付最坏路径 ≈ dettach 后 26w（设计风险，非实现错误）

- **级别:** Medium
- **阻塞主网:** 否（须披露 + 配 idle）；idle 为 0 且无 topUp 预算时视为 **是**（并入 HL-007）
- **根因:** live `onDettachFromManagedNFT` 重置 end≈now+26w；金库刻意不在 `requestWithdraw` 时 dettach，改靠 idle。实现与 `WITHDRAW_WINDOWS.md` 一致且单测覆盖「不 eager dettach」。
- **要求:** 用户文档写清最坏等待；挤兑假设；监控 `pendingWithdrawNest` vs `availableIdleNest`。

### HL-007 — 默认 `idleDepositBps=0` / `minIdleNest=0`，开放存款前未设参则偿付脆弱

- **级别:** Medium（配置）
- **阻塞主网:** **是**（若开放存款时仍为 0 且无 keeper NEST 预算）
- **根因:** 构造函数不设 skim；无 idle 时任何赎回都依赖 `topUpIdle` 或 26w 解锁。
- **要求:** 部署清单写死初始 `idleDepositBps`/`minIdleNest` 与 topUp 资金来源；guardian/owner 变更受监控。

### HL-008 — `setHevAdapter(address(0))` + `dettachForLiquidity` 可永久卡住本金路径（已复现）

- **级别:** High（owner 脚枪 / 错误配置）
- **阻塞主网:** **是**——若无代码修复且无运维禁令；修复或明确禁止置零后可降级
- **根因:** `dettachForLiquidity` 在 `hevAdapter==0` 时跳过 `withdrawVeNFT`，仍执行 `inHev=false` 与 `unlockEligibleAt=…`。链上仍 attached；之后 `NotInHev` 无法再走 vault dettach；`process` 见 `isAttached` 跳过 → 队列无法靠该 NFT 兑付。
- **要求:** `setHevAdapter` 拒绝 0；或仅在 `withdrawVeNFT` 成功后清 `inHev`；部署后监控 adapter 地址。

### HL-009 — Guardian 可调 idle 参数（含抬高 `minIdleNest` 卡 fulfill）

- **级别:** Medium
- **阻塞主网:** 否（建议收紧）
- **根因:** `setMinIdleNest` / `setIdleDepositBps` 为 `onlyGuardianOrOwner`。在余额允许下抬高 `minIdleNest` 可使 `availableIdle=0`，软阻塞兑付（有余额≥新地板校验）。
- **建议:** guardian 仅 pause；idle 参数改 onlyOwner（或 timelock）。

### HL-010 — 每笔 deposit 新建 veNFT → harvest/process O(n) 燃气

- **级别:** Medium（可扩展性 / HyperEVM ~3M block gas）
- **阻塞主网:** 否（小 TVL）；**放大用户数前是**
- **根因:** `deposit` 每次 `createLockFor` 新 NFT 并 `veNFTIds.push`；`harvest` 把**全部** id 传给 adapter；`_processWithdrawQueue` 扫描全部 NFT。
- **要求:** 合并/上限、分页 process、或限制活跃 NFT 数；压测 gas。

### HL-011 — 解锁复合增量与 `nestPrincipal` 会计不对称

- **级别:** Medium / Low
- **阻塞主网:** 否
- **根因:** dettach 时 VR 可能把 NEST share 打回 NFT，`withdraw` 实际到账可 > `nestPrincipal`；超额留在 idle 利好队列，但若未诚实 `recordCompound`，剩余持有人份额价滞后。与 HL-002 叠加则危险（乱记复合）。
- **建议:** 以链上可读增量驱动复合记账；禁止估数。

### HL-012 — `unlockEligibleAt` 用整 26w，live 为 `roundToWeek(now+MAX_LOCK)`

- **级别:** Low
- **阻塞主网:** 否（通常金库更晚、更保守）
- **要求:** fork 确认 week 对齐；若出现 `withdraw` revert，process 整笔失败，需 keeper 告警。

### HL-013 — Pause 模型符合既定安全决策

- **级别:** Info / 通过
- **阻塞主网:** 否
- **核实:** pause 阻断 `deposit` + `requestWithdraw`；仅 owner `unpause`；keeper 不可；pause 下 harvest/process/dettach/topUp 仍可用；单测 7+ 项 + 测网 smoke。

### HL-014 — 直接捐赠 NEST 不抬份额价（抗经典通胀）

- **级别:** Info / 正向
- **阻塞主网:** 否
- **说明:** 捐赠只增 ERC20 余额，进 idle 偿付路径，不改 `totalNestLocked`。与 HL-002 对比：危险的是**记账抬价**，不是捐赠。

### HL-015 — HevAdapter / NestVault owner 可换 vault/adapter；VR 源码未验证

- **级别:** Info / Medium（信任假设）
- **阻塞主网:** 否（owner 多签 + 变更监控）；VR 源码缺口保持知情
- **说明:** `HevAdapter.setVault`、`NestVault.setHevAdapter` 为标准升级面；恶意 adapter 可不真正 dettach（类似 HL-008）。VR live impl Sourcify 404。

### HL-016 — Keeper 草稿过时且权限面未在脚本中体现完整

- **级别:** Info（运维）
- **阻塞主网:** 否
- **说明:** `keeper/keeper.ts` 仍残留投票池注释；ABI 仅 `harvest`，未覆盖 `dettachForLiquidity` / `topUpIdle` / 队列告警阈值。需按主网 runbook 重写。

---

## 5. 复测清单（主网前）

- [ ] `forge test` 保持 25/25（或更新后全绿）
- [ ] 生产地址：owner / guardian / keeper / feeRecipient **四分离**，多签+2step 移交完成
- [ ] `recordCompound`：禁用或可验证改造，并有负向测试（禁止无资产抬负债）
- [ ] `setHevAdapter(0)` 拒绝或 dettach 状态机修复；回归「不可卡本金」
- [ ] 初始 `idleDepositBps` / `minIdleNest` 写入部署清单；挤兑仿真（idle 耗尽 → 缺口 → 选择性 dettach）
- [ ] 对外文案：无液态 HYPE claim；份额增值来源说明
- [ ] Fork/小额主网 rehearsal：真实 NEST `createLockFor` 原子 attach → idle 兑付 → 一次 dettach →（可 warp）unlock
- [ ] 监控：`DettachForLiquidity`、`NestCompoundRecorded`、`HevAdapterUpdated`、`Paused`/`Unpaused`、队列缺口
- [ ] Gas：N 次独立 deposit 后 `harvest`/`processWithdrawQueue` 是否逼近 3M
- [ ] Voter dettach 窗口：keeper 在投票锁窗内失败有告警与重试

---

## 6. 一句话上线建议

**内部审查结论：单测 25/25 与 pause 模型合格，idle/26w 设计方向正确；但在角色多签拆分、`recordCompound` 无证明抬债、HYPE 名实披露、adapter 置零脚枪、以及真实 HEV 兑付路径演练完成之前，不要主网开放存款。**

