# Asset Evaluation #28 — RENDER / Render Network

## Conclusion

**No-Go as a standalone RENDER Leaf for now; Watchlist / infrastructure candidate.**

RENDER has real protocol-level economic activity, but the current productive reward is attached to **Render Network node operators / compute supply**, not to ordinary RENDER holders. Render is not a PoS chain and does not provide native holder staking or a mature liquid-staking receipt. Therefore `RENDER -> hRENDER` cannot currently be justified as a rate-bearing Leaf without constructing a separate node-operator productive position.

## Latest ASR / Availability Reward check — 2026-09-10

As of the latest Render Foundation dashboard snapshot checked today:

- Latest node operator reward: **15,000 RENDER**.
- A **next node operator reward countdown is active**, indicating the reward epoch is continuing.
- RNP-015 formally defines Availability Rewards and is marked **Implemented**.
- The Foundation FAQ states that node operators receive emissions for completed rendering work and node availability, with Availability Rewards distributed according to uptime through a weighted-points system.

**Verdict: ASR is currently operating and being emitted normally at the network level.** This is not evidence of a holder-level RENDER staking yield; ASR is a node-operator reward.

## Product fit

### Gate 0

No mature canonical RENDER LST / holder staking receipt identified.

### Productive position

The economically productive position is:

`GPU node operator -> availability/work contribution -> RENDER emissions`

This is materially different from:

`RENDER holder -> staking receipt -> exchange-rate appreciation`

A HyperLeaf wrapper around ordinary RENDER would therefore create no verified productive NAV.

### BME

Render uses Burn-and-Mint Equilibrium (BME): network usage causes RENDER burns, while scheduled emissions fund node operators and other approved allocations. The Foundation dashboard currently reports cumulative burned RENDER and current node emissions. BME is an important value/utility mechanism but **must not be treated as holder yield**.

## HyperLeaf decision

`RENDER -> hRENDER` ❌ standalone

`RENDER -> dedicated Render node/operator productive position -> Position Adapter -> Leaf` ⚠️ possible future architecture, but operationally much more complex than an LST.

The second route would require authenticated ownership/control of the node position, reward accounting, uptime/work attribution, operating-cost treatment, reward withdrawal, node failure/replacement, and a conservative NAV/solvency model. It is not appropriate for the current standard asset batch.

## Key risks / verification points

1. ASR is operator-side, not holder-side.
2. No native RENDER staking yield.
3. BME burn is usage-driven value capture, not automatic Leaf exchange-rate yield.
4. Node-operator position introduces off-chain hardware/uptime/cost risk.
5. Reward attribution and custody are substantially more complex than canonical LSTs.
6. Do not use exchange Earn rates as protocol-native yield; those are provider-funded products.

## Re-entry conditions

Reconsider RENDER if one of the following becomes available:

- a mature canonical liquid-staking / productive RENDER receipt;
- a canonical, transferable node-operator position with sufficiently deterministic reward accounting;
- a HyperLeaf-specific Render compute vault whose NAV and reward entitlement can be authenticated and continuously bounded by the solvency invariant.

## Sources

- Render Foundation Dashboard: latest epoch/node rewards, supply, burns, BME metrics.
- Render Foundation FAQ: BME, node operator rewards, Availability Rewards.
- RNP-015: Availability Rewards, status Implemented.
