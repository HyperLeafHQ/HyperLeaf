# HyperLeaf TAO / Bittensor Root Basket Framework

> Status: **framework only — not a production TAO bridge or redeeming vault**.

## Why TAO is different

Bittensor's current Root Reborn design (runtime v441+) makes root staking productive through **validator-specific baskets**. A root staker's principal remains TAO staked to a validator on netuid 0. The yield is represented as a beta (β) entitlement to that validator's whole basket, and a claim sells the staker's proportional slice of the holdings at the then-realizable pool quotes and stakes the resulting TAO back to root.

This means HyperLeaf must not model TAO as a conventional single-rate LST:

```text
wrong:
TAO deposit -> shares -> global exchange rate

preferred:
Bittensor root position
  coldkey + validator hotkey + root principal
              |
              v
      validator-specific basket
              |
        beta entitlement
              |
              v
       realizable TAO quote
              |
         claim / root stake
```

The official Bittensor docs describe the same separation: root principal is ordinary root stake; basket ownership is a fraction of the whole fund; NAV is realizable from current pool depth rather than a generic spot oracle; deposits and claims are priced from the fund's actual execution path; and unclaimed β continues accruing without an automatic claim. citeturn283801search0turn283801search4

## Canonical remote data

The current framework normalizes these fields:

| Field | Meaning |
| --- | --- |
| `coldkey` | Bittensor AccountId32 for the economic owner |
| `validatorHotkey` | AccountId32 identifying the validator/fund |
| `netuid` | Must be `0` for Root Basket positions |
| `rootStakeRao` | Principal TAO staked on root |
| `betaRaw` | Raw β share/entitlement units |
| `valueTaoRao` | Current realizable TAO quote for the β position |
| `remoteBlock` | Bittensor-side block used for the snapshot |
| `specVersion` | Runtime version associated with the snapshot |
| `stateHash` | Hash commitment to the exact authenticated proof payload |

The official developer runtime documentation exposes `getBetaPosition(hotkey, coldkey)` for one staker's display-denominated β position and `getRootBasketOwed(coldkey)` for the coldkey-wide redeemable TAO quote. citeturn335523search4

## Code layout

### EVM

- `src/interfaces/ITaoRootBasketAdapter.sol` — normalized position/state boundary.
- `src/interfaces/ITaoRootStateVerifier.sol` — bridge/proof verification seam.
- `src/lz/LeafTaoRootPolicy.sol` — Root-only policy checks and listing identity.
- `src/lz/LeafTaoRootAdapter.sol` — stores authenticated snapshots and applies freshness / monotonicity checks.

### Keeper / observation

- `keeper/tao/rootBasket.ts` — typed Bittensor observer seam.

The observer intentionally does not invent a proof hash or derive NAV from external prices. A production implementation must supply the hash from the same authenticated payload consumed by the EVM verifier.

### Tests

- `test/lz/LeafTaoRootAdapter.t.sol` — verifies netuid=0, runtime version floor, snapshot monotonicity, local freshness, and verifier-only attestation.

## Security boundary

The most important design rule is:

> **Do not put Bittensor trust inside the ERC20 accounting contract.**

The EVM adapter may accept only a state produced by an authenticated verifier. That verifier must bind at least:

1. exact `coldkey`;
2. exact validator `hotkey`;
3. root/netuid = `0`;
4. root stake principal;
5. β entitlement;
6. realizable TAO quote and the basket holdings/quotes needed to reproduce it;
7. Bittensor block / runtime version;
8. replay protection / proof identity.

The verifier should reject stale, replayed, malformed, or differently encoded state. `stateHash` is a commitment field, not authentication by itself.

## Claim semantics for the eventual product

The framework deliberately stops before implementing redemption. Root Reborn's native semantics matter:

- `stake remove --netuid 0` removes **principal**; basket yield can remain separately owed.
- `root claim` realizes the accrued basket entitlement into root stake; it is not a free-balance transfer.
- There is no generic "claim 40% of the basket" primitive matching a 40% principal unstake; an implementation must reproduce the chain's per-validator entitlement semantics rather than invent proportional local accounting.
- Claim quotes are live and can move with subnet pool prices.
- A claim has a threshold and an execution-cost consideration; the canonical chain decides what can actually be realized.

These semantics are documented by Bittensor's Root Reborn guide and beta-token documentation. citeturn283801search0turn283801search4

## Why this is not a normal rate-bearing Leaf

For assets such as exchange-rate LSTs, HyperLeaf can often express yield as a share price. TAO Root Basket should instead preserve three separate economic dimensions:

```text
principal TAO
    !=
beta entitlement
    !=
current realizable TAO value
```

That separation prevents the slash/recovery watermark problem identified elsewhere in HyperLeaf from being silently recreated as a synthetic TAO exchange rate.

## Source references

- Bittensor Docs — Root Reborn: https://preview.bittensor.com/docs/guides/root-reborn
- Bittensor Docs — Beta tokens: https://www.bittensor.com/docs/concepts/beta-tokens
- Bittensor Developer Docs — runtime APIs: https://github.com/latent-to/developer-docs/blob/main/docs/subtensor-api/runtime.md
- HyperLeaf PR #4 — TAO evaluation comment `5608746483`
