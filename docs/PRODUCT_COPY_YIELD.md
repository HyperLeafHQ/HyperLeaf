# Yield copy (canonical) — must match implementation

**Implementation fact:** `NestVault.recordCompound` is **disabled** (`CompoundDisabled`). HyperLeaf does **not** currently raise hNEST share price / NAV via an on-chain compound booking path.

**Use**
- 金库代挂 Nest HEV / 锁仓由 Nest 自动化管理（不写“用户自动复投按钮”）
- Nest 侧可能仍按 Nest 规则复合；**HyperLeaf 份额价暂不因此自动上调**（直至可验证记账上线）
- Nest 公开 HYPE Spring 空投份额（在 Nest 侧按公开规则；非 HyperLeaf 内随时领 HYPE）

**Avoid**
- 自动复投 / auto-reinvest（用户侧按钮语义）
- 自动复合份额导致 NAV 上升 / auto-compound into share value（在 `recordCompound` 禁用期间）
- HyperLeaf 内「随时领取 HYPE」
- “audited / 已审计 / audit reports published”（仅可说内部审查）

Updated: 2026-09-06
