# NEST / hNEST Architecture & Economic Model

**Status:** Product architecture reference  
**Branch:** `feat/lz-oft-wrap`  
**Updated:** 2026-09-10

This document is the main architecture reference for HyperLeaf's NEST integration. It connects the protocol mechanics, hNEST accounting, Nest/HEV behavior, withdrawal/liquidity policy, HYPE accounting, product UX, operational roles, and known limitations.

It is intentionally separate from deployment checklists and source-level audit notes.

---

## 1. Executive decision

HyperLeaf should treat NEST as a **native protocol integration**, not as an external lending strategy.

The economic path is:

```text
NEST
  ↓
NestVault
  ↓
veNEST NFT
  ↓
Nest HEV managed strategy
  ↓
NEST-denominated strategy rewards / compounding
  ↓
hNEST receipt
```

The HyperLeaf product is **hNEST**, a transferable ERC-20 receipt representing a pro-rata claim on the Nest position held by the vault.

The primary user exit is the **secondary market**. The protocol-level `NestVault.requestWithdraw()` path remains an on-chain emergency/manual backstop, but it is not the normal product journey because the underlying veNEST position can require a long custody/unlock cycle.

HyperLeaf does **not** currently book an automatic increase in hNEST NAV from an asserted compound event: `NestVault.recordCompound` is disabled. Therefore the product must not advertise a continuously increasing hNEST share price until a verifiable on-chain accounting path exists.

---

## 2. What hNEST actually represents

hNEST is not:

- a rebasing token;
- a claim on a user's own veNEST NFT;
- a promise of instant NEST redemption;
- a guaranteed-NAV stablecoin;
- a liquid representation of Nest's entire future HYPE incentive stream.

Conceptually, hNEST represents a share of the **Nest principal that HyperLeaf has placed into its managed vault position**.

The key distinction is:

```text
Underlying position economics
        ≠
HyperLeaf accounting that has been verified on-chain
```

Nest may continue to compound inside its own protocol, but HyperLeaf must not convert that external economic event into a higher hNEST liability unless HyperLeaf has a verifiable accounting input and backing transition.

This is why `recordCompound` is intentionally disabled today.

---

## 3. Native Nest architecture

### 3.1 Contracts and roles

| Component | Function |
| --- | --- |
| NEST | Underlying protocol token deposited into HyperLeaf |
| NestVault | Holds protocol-owned veNEST position and mints hNEST |
| HNest | Transferable ERC-20 receipt token |
| HevAdapter | Connects the vault to Nest's live veNEST/HEV managed-NFT path |
| veNEST | Underlying locked voting position |
| Voter | Attach/detach managed-NFT operations |
| HEV strategy | Nest's managed strategy for the vault's veNEST position |
| VirtualRewarder | Tracks Nest-side locked reward entitlement; not a public HYPE claim interface |
| EpochHNestGate | Optional product-layer front door for new deposits and epoch settlement |
| Leaf Market | Secondary exit / hNEST ↔ NEST market path |

The live Nest integration uses the confirmed Nest mainnet contracts documented in `docs/HEV_ABI_PROBE.md` and `src/config/HyperEVMAddresses.sol`.

---

## 4. Deposit lifecycle

### Direct legacy vault path

The existing live NestVault is immutable and has no deposit-gate hook. A direct vault deposit therefore follows:

```text
User approves NEST
      ↓
NestVault.deposit(NEST)
      ↓
createLockFor(..., vault, managedId=1)
      ↓
veNEST NFT is attached to HEV
      ↓
NestVault mints hNEST to the depositor
```

The vault owns the underlying veNEST NFT. The user owns the hNEST receipt.

### Gated HyperLeaf path

For product flows that intentionally use the new circulation gate:

```text
User NEST
   ↓
EpochHNestGate
   ↓
NestVault
   ↓
hNEST is temporarily held by Gate
   ↓
8d / epoch settlement condition
   ↓
user claims the hNEST tranche
```

The Gate is a **front door**, not a modified version of the immutable live vault.

It must never be described as if the hNEST token itself carries a provenance-aware 8-day lock. ERC-20 hNEST has no provenance bit.

---

## 5. Three clocks that must never be conflated

### 5.1 HEV detachment clock — 4 days

`detachmentLockDuration()` is approximately **4 days**.

This governs when an attached managed NFT can enter the Nest detachment flow. It is a **custody constraint**.

It does not mean that rewards have settled, and it does not mean hNEST is liquid under the product policy.

### 5.2 Nest economic epoch — 7 days

HyperLeaf's hNEST reward accounting uses the Nest weekly epoch:

```text
Thursday 00:00 UTC → next Thursday 00:00 UTC
```

Weekly HYPE allocation is a separate product-layer accounting rail. It must not be confused with HEV detachment.

### 5.3 hNEST circulation gate — 8 days + epoch settlement

For the gated path:

```text
claimableAt = max(
    depositTimestamp + 8 days,
    epochEnd(depositTimestamp) + settlement buffer
)
```

The current implementation uses `HNestCirculation` for this calculation.

This clock exists to prevent a newly minted hNEST position from being immediately treated as a fully settled representation of an epoch-bound economic position.

---

## 6. Yield taxonomy for NEST

NEST has multiple economic surfaces. They must not be merged into one generic “APR” number.

### A. NEST principal

Principal enters NestVault and backs hNEST.

### B. veNEST / HEV compounding

Nest's HEV strategy can compound economics into the managed veNEST position. HyperLeaf currently does **not** have a verified `recordCompound` path, so this economic movement is not automatically reflected as a higher hNEST NAV.

### C. Locked reward entitlement

The live HEV/VirtualRewarder path exposes NEST-denominated locked reward balances. This is not equivalent to a user-facing HYPE ERC-20 claim.

### D. HYPE / incentive distributions

A real liquid HYPE entitlement must be backed by an actual claim ABI and a verifiable asset movement. Until that exists, HyperLeaf should not manufacture a “claim HYPE” path from Nest's internal reward accounting.

### E. Secondary-market price

hNEST can trade above or below the protocol's book backing because the market prices liquidity, lock duration, reward expectations, and exit risk.

Therefore:

```text
protocol backing value
        ≠
secondary-market price
        ≠
headline Nest pool APR
```

---

## 7. Accounting invariants

The following invariants are the core safety properties for hNEST.

### Invariant 1 — No unbacked hNEST liability

At all times, protocol-accounted hNEST liability must not exceed the backing represented by the vault's tracked NEST principal and any explicitly recognized/verifiable economic increment.

`recordCompound` remains disabled specifically because an owner/keeper must not be able to increase hNEST liability by assertion alone.

### Invariant 2 — hNEST supply is not changed by secondary-market trading

Leaf Market transfers hNEST between users. A same-chain trade must not mint/burn hNEST or mutate NestVault backing as a side effect.

### Invariant 3 — A withdrawal request is not an immediate veNEST withdrawal

Calling `requestWithdraw()` burns hNEST and queues NEST redemption. It must not eagerly detach an attached veNEST NFT when doing so would reset the underlying unlock clock.

### Invariant 4 — Detachment uses vault-side principal accounting

When a veNEST NFT is attached to HEV, the underlying `getNftState().locked.amount/end` can be zeroed by the managed-NFT flow. Vault accounting must therefore use explicitly recorded principal such as `nestPrincipal[tokenId]` rather than the attached state fields for redemption sizing/readiness.

### Invariant 5 — No accidental reward migration on hNEST transfer

Address-bound residual HYPE must settle correctly before an hNEST transfer where the current implementation uses holder-address accounting. A transfer must not allow the buyer to steal already-accrued seller reward entitlement.

### Invariant 6 — New deposit cannot receive another user's earlier epoch reward

Epoch accounting must be tranche-aware. Each gated deposit has its own `DepositTranche`; a later deposit must not extend or merge the earlier deposit's claim window.

### Invariant 7 — Fee changes cannot rewrite a closed epoch

The Gate snapshots fee bps and fee recipient when an epoch opens. Governance changes after the opening point must not retroactively rewrite that epoch's allocation.

### Invariant 8 — Keeper failure cannot permanently block finalization

`allocateHype(0)` is invalid. `finalizeHype` is permissionless after the finalization delay so a missing keeper cannot permanently trap claimable hNEST.

### Invariant 9 — The protocol does not promise a buyer

Secondary-market exit is a market mechanism, not a redemption guarantee. A UI must not imply a guaranteed NEST price, guaranteed liquidity, or guaranteed buyer.

---

## 8. Withdrawal and liquidity model

### Why direct redemption is slow

The underlying position is optimized for veNEST economics rather than instant liquidity. Detaching a managed NFT can reset the underlying lock into a long post-detachment unlock window.

Therefore the safe MVP policy is:

```text
Normal user exit → secondary market
Protocol exit     → queued redemption backstop
```

### Idle NEST

A small portion of deposits can remain idle as a shared liquidity buffer. Current deployment policy uses:

- `idleDepositBps = 100` (1%);
- `minIdleNest = 50 NEST`.

This creates explicit immediate liquidity without pretending that the entire veNEST position is immediately withdrawable.

### Detach for liquidity

`dettachForLiquidity` should happen only when the queue actually needs underlying liquidity and the 4-day HEV custody condition is satisfied.

Detachment is therefore an **exception path for liquidity management**, not the normal lifecycle of every deposit.

---

## 9. HYPE accounting policy

The protocol currently has three different meanings of “HYPE” that must stay separate:

1. **HYPE sitting as an ERC-20 balance** on HyperLeaf contracts;
2. **Nest-side economic rewards** that may be represented in NEST/veNEST accounting;
3. **A future liquid HYPE claim** if Nest actually exposes and supports one.

Only the first is directly sweepable today at the adapter layer.

`HevAdapter.sweepResidualHype()` is a residual-balance sweep. It is not a claim engine for Nest rewards.

Likewise, `HevAdapter.pendingLockedNestShare()` is explicitly NEST-denominated and must not be rendered by the frontend as “claimable HYPE”.

---

## 10. Secondary market model

Leaf Market is the primary user-facing exit for the current C1-style hNEST product.

The market should be understood as:

```text
Seller
  hNEST ─────────────→ Buyer
  ←──────────── NEST
```

The market does not:

- create hNEST;
- burn hNEST;
- move NestVault's veNEST NFT;
- book compound yield;
- claim Nest's internal reward stream;
- guarantee an NAV floor.

The buyer is effectively purchasing access to the underlying Nest position with a liquidity/lock discount determined by the market.

---

## 11. Risk matrix

| Risk | Severity | Mitigation / current state |
| --- | --- | --- |
| Long underlying veNEST exit | High | Secondary-market-first UX; idle liquidity backstop |
| Nest / HEV contract upgrade risk | High | Freeze/bind adapter configuration; monitor upstream contracts |
| Invalid reward interpretation | High | No invented HYPE claim path; explicit NEST-denominated naming |
| Unbacked NAV increase | Critical | `recordCompound` disabled |
| Gate epoch coalescing | High | Independent deposit tranches |
| Keeper failure | Medium | Permissionless epoch roll/finalization |
| Fee governance drift | Medium | Fee snapshot at epoch open |
| Secondary-market illiquidity | High | No guaranteed buyer/NAV; show liquidity state |
| Residual HYPE accounting | Medium | Separate residual index and holder settlement |
| Adapter authority change | High | Freeze while live; do not allow casual vault/adapter rewiring |
| Upstream ABI mismatch | High | `HEV_ABI_PROBE.md`, live ABI-derived interface names |
| Live vault bypasses Gate | High | Explicit UI/deployment rule: Gate is product front door, live vault remains immutable |

---

## 12. Operational roles

For mainnet, keep a four-way role split:

```text
Owner          governance/configuration
Guardian       emergency pause
Keeper         harvest/process/liquidity operations
feeRecipient   protocol fee sink
```

The deployer/hot wallet should not remain the long-term Owner.

The current mainnet deployment checklist records this separation and explicitly forbids copying testnet role collapse into production.

---

## 13. Monitoring requirements

The NEST integration should be monitored as an economic system, not merely as a contract uptime service.

### Contract / role monitoring

- Owner and pendingOwner changes
- Guardian changes
- Keeper changes
- HEV adapter changes
- deposits enabled/disabled
- pause/unpause
- fee changes
- idle buffer configuration

### Solvency monitoring

- hNEST total supply
- `totalNestLocked`
- tracked principal by veNEST NFT
- queued withdrawal NEST
- available idle NEST
- minimum idle floor
- HEV managed NFT count

### Reward monitoring

- Nest-side reward balance / pending locked NEST share
- actual HYPE ERC-20 balances
- Gate weekly allocation
- Gate fee taken
- residual-HYPE index growth

### Market monitoring

- hNEST/NEST market price
- market discount to internal book value
- market depth
- filled volume
- outstanding listings

A market discount is not automatically a protocol insolvency signal; it can represent the price of liquidity and the underlying lock duration.

---

## 14. Frontend truth table

| User-facing statement | Allowed? |
| --- | --- |
| “hNEST represents NEST placed into NestVault / HEV.” | Yes |
| “hNEST is transferable ERC-20.” | Yes |
| “Protocol redemption exists as a backstop.” | Yes |
| “Most normal exits use the secondary market.” | Yes |
| “hNEST always earns HYPE.” | No |
| “hNEST always has an 8-day lock.” | No |
| “Nest yield automatically increases hNEST NAV.” | No, until verified accounting ships |
| “HYPE is instantly claimable from Nest rewards.” | No |
| “HyperLeaf guarantees a buyer.” | No |
| “HyperLeaf guarantees a fixed NEST redemption price.” | No |
| “The Gate applies an 8-day circulation condition to deposits that use the Gate.” | Yes |

---

## 15. Current product boundary

The current intended flow is:

```text
                    ┌──────────────────────┐
                    │      NEST token       │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │     NestVault        │
                    │  veNEST + HEV hold   │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │        hNEST         │
                    │   transferable ERC20 │
                    └───────┬───────┬──────┘
                            │       │
                 primary    │       │ backstop
                 exit       │       │
                            ▼       ▼
                   ┌────────────┐ ┌──────────────┐
                   │ Leaf Market│ │ requestWithdraw│
                   │ hNEST/NEST │ │  queued NEST  │
                   └────────────┘ └──────────────┘
```

The gated deposit route sits in front of the first arrow only when the product explicitly chooses `EpochHNestGate` as the entry point.

---

## 16. What is deliberately not built yet

The following are intentionally outside the current NEST product:

- automatic hNEST NAV appreciation from unverified compound events;
- user-facing Nest HYPE claim UI without a verified ABI;
- protocol-funded guaranteed hNEST buybacks;
- guaranteed hNEST/NEST secondary liquidity;
- a second synthetic wrapper around veNEST;
- migration to a replacement `NestVaultC1` for the current live product;
- treating HEV's 4-day detachment lock as the same thing as the 8-day circulation gate.

---

## 17. Audit / verification status

This document is an architecture reference, not a security-audit certificate.

The codebase contains separate audit artifacts for:

- live Nest / HEV ABI probing;
- NestVault accounting;
- withdrawal windows;
- Gate hardening;
- product copy constraints;
- mainnet deployment procedures.

Before any Solidity/Rust change is called complete, the project requires independent code audit status to remain separate from actual build/test verification.

Recommended status vocabulary:

```text
AUDIT: PASS / FIX REQUIRED
BUILD: PASS / FAIL / UNVERIFIED
TEST: PASS / FAIL / UNVERIFIED
STATUS: VERIFIED / UNVERIFIED
```

---

## 18. Non-goals and design principles

### Principle 1 — Native beats synthetic when the native protocol already has the economic engine

Do not recreate Nest's economics inside HyperLeaf just to make the architecture look symmetrical with other listings.

### Principle 2 — Backing first, APR second

The product must be able to explain exactly what backs one hNEST before it prints an APY.

### Principle 3 — Every clock has one job

- 4d → HEV custody/detachment
- 7d → Nest economic epoch
- 8d → gated hNEST circulation
- 26w-scale timing → underlying post-detachment unlock / protocol redemption path

### Principle 4 — Never turn an observation into an accounting fact

A visible Nest-side reward balance, external dashboard APR, or keeper-supplied amount is not automatically a protocol liability or a user claim.

### Principle 5 — Secondary liquidity is a product feature, not solvency magic

Leaf Market improves exit UX, but it does not erase the underlying lock. Market price must remain independent from any promise of protocol redemption at book value.

---

## 19. Canonical related documents

- `docs/NEST_PRODUCT_POLICY.md` — current product decision and UX boundary
- `docs/CONTRACTS_README.md` — concise contract-level notes
- `docs/HEV_ABI_PROBE.md` — live Nest/HEV ABI and semantics probe
- `docs/WITHDRAW_WINDOWS.md` — withdrawal queue and idle-liquidity model
- `docs/DEPLOYMENT_CHECKLIST.md` — production roles and deployment configuration
- `docs/INTERNAL_AUDIT_GATE_v1.md` — Gate security review
- `docs/PRODUCT_COPY_YIELD.md` — canonical yield/UI wording
- `docs/YIELD_OWNERSHIP.md` — general HyperLeaf yield ownership model

---

## Bottom line

HyperLeaf's NEST product is best understood as a **liquid receipt over a protocol-native, long-duration veNEST position**.

The product's competitive edge is not inventing a higher NEST APR. It is turning an otherwise illiquid Nest position into a transferable asset while maintaining strict boundaries between:

```text
Nest economics
HyperLeaf accounting
secondary-market liquidity
and user-facing claims
```

That separation is the core security property of the integration.
