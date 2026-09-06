# Hyperleaf NestVault — 内部审查 v1 复测

- **日期:** 2026-09-06 (Asia/Shanghai)
- **对照:** `INTERNAL_AUDIT_v1.md` + `AUDIT_FIXES_v1.md`
- **提交:** `7c82ba1`（本机与声称的 GitHub main）
- **证据:** 本机 `forge test` → **35/35 PASS**

## 逐项

| ID | 原级别 | 复测 | 阻塞开存？ |
|----|--------|------|------------|
| HL-002 `recordCompound` | Critical | **通过** — 函数恒 `revert CompoundDisabled()`；单测防穿仓 | 否（代码侧） |
| HL-003 dettach 上限 | High | **通过** — `cap = gap*(1+bufferBps)`；idle 覆盖 early return | 否（代码侧）；仍须监控 |
| HL-004 HYPE 命名 | High | **通过** — `sweepResidualHype` / `pendingLockedNestShare` 等 | 宣传液态 HYPE 则仍阻塞产品 |
| HL-005 Mock 默认 26w | High | **通过** — `liveDettachReset` 默认 true | 真实 e2e 仍缺口（见下） |
| HL-007 deposits 门闩 | Medium | **通过** — `depositsEnabled` 默认 false，仅 owner 开 | 开存前必须配 idle（清单） |
| HL-008 adapter(0) 脚枪 | High | **通过** — `setHevAdapter(0)` 拒；`inHev` 仅成功 `withdrawVeNFT` 后清 | 否（代码侧） |
| HL-009 guardian idle | Medium | **通过** — idle 仅 `onlyOwner`；guardian 仅 pause | 否 |
| HL-001 角色拆分 | Critical ops | **约定已确认，部署未验** | **是** — 直至主网地址清单落地 |

## 仍未关闭（开存 / 放大 TVL）

1. **HL-001 部署核验：** Owner/Guardian 用户两把互异 EOA、Keeper 热钱包、fee 独立、Ownable2Step 移交后再 `setDepositsEnabled(true)`。
2. **真实 Nest HEV e2e：** deposit→queue→dettach→26w→fulfill 未完整跑通（Mock≠live 风险降了，未消）。
3. **产品：** 禁止宣传用户可领液态 HYPE。
4. **运维：** keeper runbook（queue/dettach/topUp）与事件监控。

## 结论

**本批代码修复复测通过。** 原 Critical/High 代码项（002/003/008 等）已关门。  
**主网开放存款仍阻塞在：部署角色落地 + idle 参数 +（建议）真实兑付演练，而非上述已修漏洞。**
