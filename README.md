# HyperLeaf

**Yield-bearing asset infrastructure for HyperEVM.**

HyperLeaf turns productive, locked, delayed, or otherwise difficult-to-trade positions into explicit **Leaf** assets on HyperEVM. A Leaf is not a generic wrapper: it represents a defined economic claim, including its principal, yield, lock period, withdrawal path, and market risk.

> **HyperLeaf does not promise liquidity. It provides infrastructure for markets around otherwise illiquid claims.**

App: [hyperleaf.finance](https://hyperleaf.finance) · X: [@HyperLeafHQ](https://x.com/HyperLeafHQ)

> **Status:** early-stage infrastructure. HyperEVM mainnet deployments are deliberately capped and rolled out one path at a time. **Contracts are not externally audited. Do not deposit funds you cannot afford to lose.**

---

## What HyperLeaf is building

HyperLeaf's core job is to bring productive or otherwise constrained positions into a common HyperEVM-native asset format without hiding the underlying risks.

The asset model is intentionally split into four peer paths:

- **L — Liquid receipt:** the underlying protocol supports direct redemption.
- **C1 — Market exit:** there is no protocol redemption; exit depends on a buyer in a claim market.
- **C2 — Queued exit:** the Leaf can be burned into the underlying claim, but the protocol withdrawal remains subject to its queue or cooldown.
- **Pre — Pre-TGE claim:** a claim on pre-TGE points or similar future token economics, with settlement determined by the eventual TGE outcome rather than an existing redemption route.

The key rule is **economic fidelity**: a Leaf or claim should preserve the actual underlying economics, including rate accrual, lock periods, queue mechanics, bridge constraints, settlement conditions, and loss conditions. HyperLeaf does not manufacture a 1:1 redemption promise where the source protocol does not provide one, and it does not maintain a permanent treasury bid or NAV floor.

---

# Current progress

## Live / deployed

### hNEST

The current native production anchor is **hNEST on HyperEVM 999**, deployed with a deliberately small cap.

`NEST → NestVault → HEV / veNEST → hNEST`

hNEST is a C1-style product: the underlying position is productive but does not expose a UI instant-redeem path. Exit is through the market, while the underlying staking / withdrawal constraints remain explicit.

Current HyperEVM 999 addresses:

| Contract | Address |
| --- | --- |
| NestVault | `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` |
| HNest | `0x2101621F51D7E05518D6680C62d04Ad47bC4e05D` |
| HevAdapter | `0xc89273ACB22a4e1df81A396FE0Bf6eD6E2CA6fD2` |
| NEST | `0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035` |

### Base → HyperEVM L path

The first production cross-chain L paths are now established:

- **hxSQUID — Live v3**
- **hAVNT — Live**

Both follow the same Base corridor proven by the mainnet canary, with conservative caps and final owner / operational checks before unrestricted rollout.

### Deployment discipline

HyperLeaf deliberately moves slower than feature development:

`source verification → accounting review → fork / smoke tests → bridge configuration → cap / quota checks → deploy → post-deploy verification`

A green unit-test suite or a feature branch is not, by itself, a production approval.

---

# Current rollout order

The mainline roadmap is **asset-by-asset**, not a general-purpose framework-first roadmap.

### Phase 0 — Mainnet canary

`hCANARY / LEAFTEST` on Base ↔ HyperEVM 999 proves the real LayerZero security stack with a tiny cap and closes after redemption. It is a test instrument, not a reusable production listing.

### Phase 1 — Proven Base L paths

`hxSQUID → hAVNT`

These reuse the already-proven Base corridor and establish the first real cross-chain Leaf integrations.

### Phase 2 — Rate-bearing L assets

`hgSOON → hsWBERA`

These use share / asset conversion accounting with the source protocol's yield skim. `hcbETH` is parked because Base cbETH does not expose the required `exchangeRate` path. `hslisBNB` follows the same BSC corridor later and wraps **Lista slisBNB only**, never native BNB.

### Phase 3 — Additional mature L paths

`hsAVAX → hstkwaUSDC → hLBTC`

These add Avalanche and Ethereum integrations with asset-specific rate logic, reward accounting, decimals, and jump protection rather than forcing them through a generic adapter assumption.

### Phase 4 — C1 claim markets

`BLUAI4Y → hORDER`

These assets do not have an honest protocol redemption path, so the correct product is a **claim market**, not a synthetic redemption guarantee. `hORDER` is Arbitrum-only and uses the dedicated inbound lockbox path; there is no CREATE2 twin on another chain.

### C2 — Queued claims

C2 assets are the peer class for positions whose underlying redemption is real but delayed by a queue or cooldown. They are added only when the burn / exit path and its timing semantics can be verified on-chain.

### Pre — Pre-TGE claims

Pre-TGE claims are a peer asset class alongside **L / C1 / C2**, not a separate liquidity product.

The current canary is **Variational points**, with the ticker format `hPre{Token}Pts{tier}x{price}` (for example, `hPreVarPts2x20`). The current tiers are **1x and 2x** only. Deal price is free discovery above the $1 floor; the market aggregates depth by deal price and tier, while each seller series remains its own ERC-20 claim.

The standalone implementation is being developed on `feat/premarket`: seller collateral and buyer payments are held in bilateral escrow, claims can trade before TGE, and settlement follows resolver-confirmed delivery or default rules.

Current implementation snapshot:

- Branch: `feat/premarket`
- Reviewed snapshot: `811a182`
- Scope: standalone `src/premarket/*`
- Not deployed
- Not imported into the live Leaf path

Before production use, the remaining delivery and settlement accounting hardening must be completed together with stronger invariant and edge-case testing.

### NFT and special-position paths

The next non-standard family is **ve-NFT / NFT lockbox** infrastructure. `hveAERO` is being developed with `LeafNftLockbox`; the intended mode is permanent NORMAL wrapping, not a generic fungible conversion. Other NFT claims such as `hveUP` follow only after the lockbox path is proven.

### Phase 5 — Solana

**hJitoSOL** is the first Solana target.

The model is a rate-bearing LST: the Leaf follows the stake-pool share rate rather than pretending to be a fixed 1:1 SOL claim. The Solana integration uses its own program / lockbox path and LayerZero endpoint rather than reusing the EVM adapter unchanged.

Later Solana candidates such as JupSOL, mSOL, and VRT-based positions remain behind hJitoSOL because their share, queue, or slash semantics require additional verification.

---

# Market model

For C1 and other non-redeemable claims, HyperLeaf is developing a peer claim-market model rather than promising liquidity itself.

The design direction is:

`Leaf / claim → market participants → negotiated exit`

The protocol does not seed a permanent HyperEVM AMM, does not act as an always-on buyer, and does not create a treasury NAV floor. The market exists to make the underlying economic claim tradable, not to erase its liquidity risk.

Pre-TGE claims use a specialized bilateral-escrow settlement path because the final official token and conversion rate do not exist until TGE resolution.

---

# Security model

HyperLeaf is **not trustless today**.

Early deployment intentionally uses bounded owner / guardian / keeper powers, small caps, operational checks, and asset-specific configuration. The long-term direction is to replace discretionary assumptions with explicit constraints where practical.

> **Prefer a hard constraint over an admin promise.**

Core principles:

- **No fake liquidity.** HyperLeaf does not promise an AMM, treasury bid, or NAV floor.
- **Listing isolation.** An issue in one asset path should not silently become a global accounting assumption.
- **Economic fidelity.** Rate accrual, principal, queues, lock periods, bridge state, and market-exit conditions remain explicit.
- **Asset-specific verification.** Different protocols get different adapters and tests when their economics differ.
- **Production discipline.** New code stays off `main` until its specific deployment and verification path is complete.

---

# Roadmap

## Near term

1. Complete the currently ordered L rollout after the proven Base paths.
2. Continue Phase 2 / 3 integrations one asset at a time, with conservative caps and source-specific accounting.
3. Move the first C1 listings through the claim-market path and validate real secondary-market behavior.
4. Finish the NFT lockbox canary path for `hveAERO` before expanding the ve-NFT family.
5. Bring **hJitoSOL** through the Solana mainnet path after the EVM 0–4 rollout is sufficiently proven.
6. Continue hardening the standalone Pre implementation before considering any production deployment.

## Mid term

- Expand the catalog with additional high-confidence L / C1 / C2 assets and carefully evaluated Pre-TGE claims from Ethereum, BSC, Avalanche, Berachain, Robinhood, Solana, and other supported environments.
- Add chain-specific integrations where the underlying protocol economics require their own lockbox, NFT, queue, or accounting model.
- Improve permissionless operational flows such as harvesting without weakening asset-level accounting controls.
- Gradually reduce admin dependence through stronger invariants, operational guards, and governance boundaries.

## Long term

HyperLeaf is intended to become an **ingress layer for productive assets and explicit claim markets on HyperEVM**:

```text
Productive / constrained position
            ↓
   explicit economic claim
            ↓
     HyperEVM Leaf / Claim
            ↓
     markets + collateral + integrations
```

The goal is not to make every asset look liquid. The goal is to make productive and constrained claims **legible, composable, and tradable without hiding their risks**.

---

# Repository guide

| Area | Purpose |
| --- | --- |
| `src/` | Core contracts and live deployment infrastructure |
| `src/premarket/` | Standalone pre-TGE market implementation on feature branches |
| `docs/` | Technical design and operational notes |
| `listings/` | Listing catalog and asset configuration |
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

HyperLeaf is experimental software. Integrations may be incomplete, paused, capped, parked, or blocked. Feature branches are not production deployments. External audits do not currently cover the full system. Read the relevant listing and product documentation before interacting with any deployment.
