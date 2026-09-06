# Yield copy (canonical) — must match implementation

**Implementation fact:** `NestVault.recordCompound` stays **disabled** (`CompoundDisabled`). Unbacked keeper numbers must never raise NAV.

**Verified compound (this branch, not live until NestVault v2):** `bookVerifiedYield` reads `HevAdapter.pendingLockedNestShare` deltas. Protocol mints **1%** of that NEST as hNEST to `feeRecipient`; **99%** raises share price. Donations / `topUpIdle` are not yield.

**HYPE:** Nest pays HYPE to veNEST that increased this epoch. That is **not** a holding-time reward. New deposits wait one Nest week in `EpochHNestGate`, then receive standard transferable hNEST + that week's HYPE (1% protocol / 99% depositors). Circulating hNEST is a normal ERC-20 — the gate does not freeze transfers. Residual ERC20 HYPE swept into the vault (usually 0) is MasterChef'd to current holders; do not advertise “claim HYPE anytime”.

**Use**
- 金库代挂 Nest HEV / 锁仓由 Nest 自动化管理（不写“用户自动复投按钮”）
- 新存 NEST：进 gate，等当周结算后再拿可流通 hNEST + 当周新锁对应的 HYPE
- 已流通 hNEST：吃 NEST 复合净值（99%）+ 复合增量对应的那一小份 HYPE（有领取口之后）
- 协议收入：只抽质押收益的 1%；进出不加协议费

**Avoid**
- 自动复投 / auto-reinvest（用户侧按钮语义）
- 把 Nest 当周 HYPE 按持仓时间分给所有 hNEST（会让二级市场买旧份额的人分走新存款人的 HYPE）
- 给 hNEST 加转账锁 / 非标准 ERC-20
- HyperLeaf 内「随时领取 HYPE」
- “audited / 已审计 / audit reports published”（仅可说内部审查）

Updated: 2026-09-07
