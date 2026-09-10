# HyperLeaf Asset Evaluation #23 — GT / Gate

Status: **Selected — P1 research candidate; no mature canonical GT LST identified. This is a market-gap opportunity for HyperLeaf.**

## 1. Executive conclusion

GT is the native asset of GateChain and has a productive native staking path. Unlike POL, current research did not identify a mature, canonical, liquid GT staking derivative comparable to sPOL.

This is therefore not an LST-selection case. It is a **market-gap case**:

```text
GT
 ↓
GateChain native staking
 ↓
HyperLeaf-controlled productive position
 ↓
Position Adapter
 ↓
C1/C2 Leaf depending on redemption topology
 ↓
hGT
```

HyperLeaf should not manufacture an LST-shaped token and call it canonical. The product opportunity is to create a transparent, collateralized Leaf around a real GateChain staking position, if custody and authenticated state can be made sufficiently robust.

## 2. Asset / network thesis

GT is GateChain's native token and is used for gas and network economics. GateChain is EVM-compatible and provides native staking / validator delegation.

The productive source position is therefore network staking, not GT spot appreciation.

Required accounting separation:

1. GT principal;
2. staking rewards;
3. validator/delegation state;
4. unbonding / withdrawal value;
5. HyperLeaf fee;
6. GT market price;
7. Leaf secondary-market price.

## 3. LST-first investigation

### Result: no mature canonical GT LST identified

The research target was specifically:

- official/canonical GT liquid staking token;
- transferable ERC-20 staking receipt;
- exchange-rate or rebasing reward accounting;
- meaningful liquidity;
- deterministic redemption path;
- canonical cross-chain representation.

No candidate currently meets all of these requirements with sufficient confidence for Gate 0.

Gate Chain / Gate Layer may have future liquid-staking products, but an announced or coming-soon product is not treated as a mature LST.

Therefore:

`canonical GT LST > native staking > spot wrapper`

still applies, but **no canonical LST currently wins**.

## 4. Why this is interesting for HyperLeaf

The absence of a mature GT LST does not weaken the opportunity; it changes the product thesis.

If GateChain staking can be controlled by a HyperLeaf strategy vault and the resulting position can be authenticated to HyperEVM, HyperLeaf can provide the missing liquid/accounting abstraction:

```text
GT holder
  ↓
deposit GT
  ↓
GateChain validator staking
  ↓
verified productive NAV
  ↓
authenticated cross-chain state
  ↓
hGT
```

This would give GT holders a standardized, composable representation of a productive staking position without pretending that an existing third-party wrapper is canonical.

## 5. Leaf class

Do **not** assume Liquid / Rate-bearing merely because staking rewards exist.

Initial classification: **C1/C2 pending exit verification**.

The final class depends on:

- validator unstaking period;
- delegation transferability;
- whether staking rewards compound into principal;
- whether a strategy can maintain a liquid GT buffer;
- whether HyperLeaf can honor redemption without relying on secondary-market GT price;
- cross-chain message freshness.

If the position has deterministic asynchronous redemption, C2 is the conservative default. If HyperLeaf deliberately disables user exit and exposes a secondary market, C1 can be used under product policy.

## 6. Required architecture

```text
GateChain

GT
 ↓
GateChain Staking / Validator Delegation
 ↓
GT Position Adapter
 ↓
Strategy Vault
 ↓
Authenticated State / Custody Boundary
 ↓
HyperEVM
 ↓
hGT
```

The adapter must value the actual staking position. It must not use:

- GT spot price as NAV;
- an arbitrary GT wrapper;
- an unauthenticated bridge balance;
- an exchange's staking receipt;
- a future/announced LST as if already deployed.

Core invariant:

`totalLeafLiability <= verified economically realizable GT staking NAV`

## 7. Security gates

Before production:

- verify GateChain staking contract / validator manager;
- verify delegation ownership and withdrawal rights;
- verify reward calculation and compounding;
- verify validator selection / concentration limits;
- verify slashing or validator-failure exposure;
- verify unbonding queue and redemption latency;
- verify admin / upgrade authorities;
- verify source-side custody;
- verify authenticated source-state messaging;
- verify replay protection and freshness bounds;
- verify HyperEVM liability accounting;
- stress test validator failure, reward decrease and delayed redemption.

## 8. Product positioning

This should be positioned internally as a **market-gap asset** rather than as an LST integration.

The strongest thesis is:

> GateChain has a native productive GT staking economy, but the market lacks a mature canonical liquid representation. HyperLeaf can potentially fill that representation layer while keeping the backing position explicit and verifiable.

This is materially different from supporting an existing LST such as sPOL.

## 9. Final decision

**GT = SELECTED — P1 research candidate.**

**No mature canonical GT LST found.** This is a positive product signal: there is potentially a representation gap for HyperLeaf to fill.

Do not deploy yet. First build and verify the GateChain native staking position adapter and exact withdrawal/accounting model. If a canonical GT LST launches later, re-run Gate 0 and prefer it over the self-built native staking route.
