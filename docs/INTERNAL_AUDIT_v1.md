# Hyperleaf NestVault / hNEST — 内部审查 v1

- **日期:** 2026-09-06 (Asia/Shanghai)
- **性质:** 内部审查（非外部专业审计）
- **范围:** `src/NestVault.sol` / `HNest.sol` / `HevAdapter.sol` + 单测 + testnet-998 演练记录 + 交接文档
- **证据:** `forge test` → **25/25 PASS**（本机 2026-09-06）
- **对照材料:** `docs/AUDIT_HANDOFF.md` 等（作线索，结论独立）

## 总评（上主网）

**当前阻塞主网正式开放存款。** Pause 模型与 idle/dettach 设计方向正确，单测与测网 pause 演练通过；但生产密钥分离未就绪、HYPE 收益路径名实不符、keeper 面过宽。满足下方「主网前门禁」后再开放。

## 发现

### HL-001 — 生产角色必须拆分多签（测网仍同 EOA）
- **级别:** Critical（运维/信任）
- **阻塞主网:** **是**
- **事实:** testnet-998 上 owner/guardian/keeper/feeRecipient 均为同一 EOA；代码允许该配置。
- **要求:** owner 与 guardian 分属独立多签；keeper 热钱包权限最小化且可轮换；feeRecipient 独立。

### HL-002 — Keeper 可点燃 26w 时钟并改写份额会计
- **级别:** High
- **阻塞主网:** **是**（若 keeper 为单 EOA/无监控）
- **根因:** `dettachForLiquidity` 主动 dettach → 锁定期重置 ~now+26w；`recordCompound` 可无资产调高 `totalNestLocked` 抬份额价。
- **要求:** keeper 操作 runbook + 监控告警；考虑 `recordCompound` 需可验证来源或双人；恶意/误操作 dettach 的应急预案。

### HL-003 — `pendingHype` / `claimHype` 名实不符
- **级别:** High（产品诚实 / 集成误导）
- **阻塞主网:** **是**（若对外宣传液态 HYPE 收益）
- **事实:** Adapter `claimHype` 仅扫 adapter 上残余 HYPE ERC20；VR pending 为 **NEST share**，无用户液态 HYPE/MEGAHYPE ABI。
- **要求:** UI/文档改名或明确披露；或等真实 claim ABI 再宣传 HYPE Spring 收益。

### HL-004 — Guardian 可改 idle 参数（含抬高 `minIdleNest` 卡队列）
- **级别:** Medium
- **阻塞主网:** 否（建议修）
- **事实:** `setMinIdleNest` / `setIdleDepositBps` 为 `onlyGuardianOrOwner`。抬高 `minIdleNest` 至接近余额可暂阻塞 fulfill（有余额校验）。
- **建议:** `minIdleNest` 仅 owner（或 Timelock）；guardian 只保留 pause。

### HL-005 — 大额赎回依赖 idle；否则 dettach 后最长 ~26w
- **级别:** Medium（设计/偿付）
- **阻塞主网:** 否（须披露 + 参数）
- **要求:** 上线前设定合理 `idleDepositBps`/`minIdleNest`；文档写清队列与最坏等待；压测挤兑。

### HL-006 — `setHevAdapter` 可替换适配器
- **级别:** Medium（owner 信任）
- **阻塞主网:** 否（owner 多签 + 变更监控）

### HL-007 — Pause 模型符合既定设计
- **级别:** Informational / 通过
- **阻塞主网:** 否
- **核实:** guardian/owner 可 pause；仅 owner unpause；keeper 不能；pause 挡 deposit + requestWithdraw；测网 smoke 与单测覆盖。

### HL-008 — e2e fork（真实 NEST：存→队→dettach→26w→兑付）未完成
- **级别:** Low / 缺口
- **阻塞主网:** 建议完成后再放大 TVL；小额可带风险上线需用户知情。

## 主网前门禁清单

- [ ] owner / guardian / keeper / feeRecipient 生产多签分离并写入部署清单
- [ ] 对外文案与 UI：禁止暗示已有用户可领液态 HYPE，除非 ABI 落地
- [ ] keeper 监控：dettach / recordCompound / setHevAdapter / pause
- [ ] idle 参数与挤兑假设文档化；建议收紧 guardian 对 minIdle 的权限
- [ ]（推荐）真实 HEV fork 全流程跑通并归档

## 一句话

**内部审查结论：测网骨架与 pause 演练合格；在密钥分离、HYPE 披露、keeper 管控到位前，不建议主网开放存款。**
