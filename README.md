# HyperLeaf

**Yield-bearing asset infrastructure for HyperEVM.**

HyperLeaf turns productive, locked, delayed, or otherwise difficult-to-trade positions into explicit **Leaf** assets on HyperEVM. A Leaf is not a generic wrapper: it represents a defined economic claim, including its principal, yield, lock period, withdrawal path, and market risk.

> **HyperLeaf does not promise liquidity. It provides infrastructure for markets around otherwise illiquid claims.**

App: [hyperleaf.finance](https://hyperleaf.finance) · X: [@HyperLeafHQ](https://x.com/HyperLeafHQ)

> **Status:** early-stage infrastructure. Mainnet / HyperEVM 999 deployments are deliberately capped and rollout is incremental. Most new integrations remain on feature branches until their accounting, bridge path, and operational tests are verified. **Contracts are not externally audited. Do not deposit funds you cannot afford to lose.**

---

## What HyperLeaf is building

HyperLeaf has two complementary tracks:

### 1. Leaf infrastructure

Bring productive assets from Base, BSC, Ethereum, Avalanche, Berachain, Solana and other supported environments into a HyperEVM-native market format.

The current listing model is intentionally split into:

- **L — Liquid receipt:** direct protocol redemption where supported.
- **C1 — Market exit:** no protocol redemption; exit depends on a market participant.
- **C2 — Queued exit:** burn the Leaf and wait for the underlying withdrawal window.

The economic rule is simple: **preserve the underlying claim and make its risks explicit.** HyperLeaf does not turn a locked position into a fake 1:1 spot token and does not run a permanent treasury bid.

### 2. Market infrastructure

HyperLeaf is also building reusable market primitives around productive and pre-TGE claims:

- Claim / C1 market infrastructure for otherwise illiquid positions.
- Generic LP position-management infrastructure separating **strategy → policy → venue adapter**.
- Stable-asset risk / exit policy infrastructure that sits below the market rather than pretending to be a treasury bid.
- A standalone **Pre-Market Guarantee Market** for pre-TGE points, currently developed off-main.

These are separate product layers. New market infrastructure does not automatically become part of the live Leaf deployment path.

---

# Current progress

## Live / deployed

### hNEST

The current production anchor is **hNEST on HyperEVM 999**, with a deliberately small cap.

`NEST → NestVault → HEV / veNEST → hNEST`

The product preserves the underlying staking / withdrawal constraints rather than promising instant 1:1 redemption.

Current HyperEVM 999 addresses:

| Contract | Address |
| --- | --- |
| NestVault | `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` |
| HNest | `0x2101621F51D7E05518D6680C62d04Ad47bC4e05D` |
| HevAdapter | `0xc89273ACB22a4e1df81A396FE0Bf6eD6E2CA6fD2` |
| NEST | `0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035` |

### Rollout discipline

Live deployment is intentionally slower than feature development:

`source verification → accounting review → fork / smoke tests → bridge configuration → cap / quota checks → deploy → post-deploy verification`

Feature branches are not treated as production merely because the code compiles or a unit-test suite is green.

---

# In progress

## L / C1 / C2 integrations

The repository currently contains a growing set of researched and partially implemented listing paths. The deployment order is intentionally conservative and can change as bridge, venue, and accounting evidence improves.

Near-term examples already in the engineering pipeline include:

`hxSQUID → hAVNT → hcbETH → hgSOON → hsWBERA → hsAVAX → hLBTC → hstkwaUSDC → BLUAI4Y → hORDER → specialized EVM assets → hJitoSOL`

A number of additional assets remain **watch / parked / blocked** because their staking, reward, queue, NFT, cross-chain-holder, or bridge mechanics need a different implementation rather than a superficial wrapper.

Detailed asset evaluation history remains tracked in **Issue #7** and the corresponding repository docs / listing catalog.

---

## Generic LP position management

A reusable LP-management framework has been developed as a separate branch / PR rather than being mixed into the core listing path.

The intended abstraction is:

```text
Strategy chooses WHEN / WHERE
        ↓
Manager enforces WHETHER
        ↓
Adapter implements HOW
```

The manager boundary includes authorization, cooldowns, deadlines, token spend caps, slippage limits, output floors, and adapter post-conditions. Concrete DEX integrations stay separate until venue-specific accounting and fork tests are available.

---

## Stable-asset protection

HyperLeaf is also building a separate policy layer for stable-asset-backed Leaf markets.

The purpose is to distinguish:

- external peg health;
- primary redemption capacity;
- immediately available exit coverage;
- stale / degraded evidence;
- ordinary market liquidity discounts versus underlying impairment.

This layer is **not** an AMM, not a treasury standing bid, and not a second stablecoin. Concrete asset adapters are expected to arrive separately with evidence-backed tests.

---

## Solana

Solana is treated as a separate integration domain rather than pretending the EVM lockbox model is reusable unchanged.

The first major target is **hJitoSOL**, using a rate-bearing LST model and chain-specific share / asset accounting. More Solana assets can follow after the lockbox and accounting path is proven.

Long-window or slash-sensitive Solana claim assets remain later-stage work because their queue and loss semantics do not fit a simple EVM LST wrapper.

---

# New product: Pre-Market Guarantee Market

A standalone pre-TGE market is under active development on **`feat/premarket`**, not on `main`.

Current implementation target:

```text
Seller
  ↓ locks collateral
Claim series token
  ↓ primary / secondary trading
Buyer exposure
  ↓ TGE resolution
48h delivery window
  ├── SETTLED → official token
  └── DEFAULTED → escrow refund + collateral penalty
```

The current design uses **bilateral escrow**:

- Seller collateral is locked before claims are issued.
- Primary buyer payments are escrowed by the protocol.
- The seller does not receive buyer funds before settlement.
- The resolver identifies the official TGE token and points-to-token rate.
- Each series gets its own 48-hour delivery window.
- VOID / EXPIRED paths unwind both sides rather than inventing a token conversion when no honest per-point rate exists.
- The design explicitly excludes seller-held inventory from the terminal buyer pool.

Current engineering snapshot:

- Branch: `feat/premarket`
- Reviewed implementation commit: `c26f4f8`
- Scope: standalone `src/premarket/*`
- Not deployed
- Not imported by live Nest / Gate / Leaf Market code

The current branch has already gone through product review and code-level audit rounds. Before any production deployment, the remaining accounting and delivery hardening must be resolved and backed by stronger invariant / edge-case tests.

---

# Security model

HyperLeaf is **not trustless today**.

The system deliberately uses owner / guardian / keeper powers where they are needed for an early, capped deployment. The engineering direction is to replace discretionary assumptions with explicit constraints wherever possible:

> **Prefer a hard-coded constraint over an admin promise.**

Important principles:

- **No fake liquidity.** HyperLeaf does not promise an AMM, treasury bid, or NAV floor.
- **Listing isolation.** One listing's accounting or pause state must not silently become a global assumption.
- **Economic fidelity.** Principal, realized yield, lock periods, bridge state, and market-exit conditions remain explicit.
- **Deployment discipline.** New code stays off `main` until its specific verification path is complete.

Public trust / admin-reduction planning is tracked separately in the project's governance and roadmap work.

---

# Roadmap

## Near term

1. Continue the one-listing-at-a-time rollout of verified Leaf integrations.
2. Finish the next L paths and the highest-confidence C1 market-exit integrations.
3. Prove the Solana lockbox / rate-accounting path with hJitoSOL.
4. Expand permissionless harvesting and reusable execution infrastructure without weakening accounting controls.
5. Finish the remaining pre-market settlement / delivery accounting hardening on `feat/premarket` before considering any production deployment.

## Mid term

- Make Leaf assets easier for other HyperEVM protocols to integrate as collateral, LP inventory, and margin collateral.
- Move technical reference material from README into a canonical Wiki / docs surface.
- Reduce admin dependence through harder invariants, stronger operational guards, and progressively safer governance boundaries.
- Add more chain-specific adapters where the underlying economics justify them.

## Long term

HyperLeaf is intended to become an **ingress layer for productive assets and claim markets on HyperEVM**:

```text
Productive position
      ↓
explicit economic claim
      ↓
HyperEVM Leaf / Claim
      ↓
markets + collateral + LP + integrations
```

The goal is not to make every asset look liquid. The goal is to make productive claims **legible, composable, and tradable without hiding their risks**.

---

# Repository guide

| Area | Purpose |
| --- | --- |
| `src/` | Core contracts and live deployment infrastructure |
| `src/premarket/` | Standalone pre-TGE market implementation on feature branches |
| `docs/` | Technical design and operational notes |
| `listings/` | Listing catalog / configuration references |
| `keeper/` | Off-chain keeper / execution infrastructure |
| `solana/` | Solana-specific integration work |
| `test/` | Unit and invariant tests |

Key references:

- [Asset evaluations / integration history — Issue #7](https://github.com/HyperLeafHQ/HyperLeaf/issues/7)
- [Trustless roadmap — Issue #6](https://github.com/HyperLeafHQ/HyperLeaf/issues/6)
- [`docs/ROADMAP.md`](docs/ROADMAP.md)
- [`listings/catalog.json`](listings/catalog.json)

---

## Disclaimer

HyperLeaf is experimental software. Integrations may be incomplete, paused, capped, or intentionally left off `main`. External audits do not currently cover the full system. Read the relevant listing / product documentation before interacting with any deployment.
