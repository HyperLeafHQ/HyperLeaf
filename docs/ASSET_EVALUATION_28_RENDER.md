# Asset Evaluation #28 — RENDER / Render Network

**Conclusion:** No-Go as a standalone RENDER Leaf for now; Watchlist / infrastructure candidate.

RENDER's productive reward is attached to Render Network node operators / compute supply, not ordinary RENDER holders. Render is not a PoS chain and has no mature canonical holder LST. Therefore `RENDER -> hRENDER` is not currently a rate-bearing Leaf case.

## Latest ASR check — 2026-09-10

The latest Render Foundation dashboard shows:
- Latest node operator reward: **15,000 RENDER**.
- A **next node operator reward countdown is active**.
- RNP-015 Availability Rewards is marked **Implemented**.
- Foundation documentation states node operators receive emissions for rendering work and node availability; Availability Rewards use uptime-based weighted points.

**Verdict: ASR is currently operating and being emitted normally at the network level.** ASR is a node-operator reward, not holder-level RENDER staking yield.

## Product fit

`GPU node operator -> availability/work contribution -> RENDER emissions`

is the productive position. This is materially different from a liquid staking position such as `RENDER holder -> staking receipt -> exchange-rate appreciation`.

BME creates usage-linked RENDER burns and scheduled emissions, but burn/value capture is not holder yield and cannot be used to create Leaf exchange-rate liabilities.

## HyperLeaf decision

`RENDER -> hRENDER` ❌ standalone.

A future route could be:

`RENDER -> dedicated Render node/operator productive position -> Position Adapter -> Leaf`

but this would require authenticated node custody/control, uptime/work attribution, reward accounting, operating-cost treatment, reward withdrawal, node failure/replacement, and conservative NAV verification. It is materially more complex than the current LST/vault batch.

## Re-entry conditions

Reconsider if a mature canonical RENDER productive receipt appears, or if HyperLeaf builds a dedicated Render compute vault with authenticated reward entitlement and continuous solvency verification.

## Sources

- Render Foundation Dashboard — current node rewards, emissions, burns and supply.
- Render Foundation FAQ — BME, node operator rewards and Availability Rewards.
- RNP-015 — Availability Rewards; status Implemented.
