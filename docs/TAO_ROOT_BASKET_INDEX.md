# TAO Root Basket Code Index

Related asset evaluation: **PR #4 / comment `5608746483` — HyperLeaf Asset Evaluation #05 — TAO (Bittensor)**.

## Implementation PR

- PR: **#48 — `feat: add TAO Root Basket verification framework`**
- Branch: `feat/tao-root-basket-framework`
- Scope: framework only; no production bridge, no production redemption path.

## Files

| Area | File | Role |
| --- | --- | --- |
| EVM interface | `src/interfaces/ITaoRootBasketAdapter.sol` | Normalized remote Root Basket position boundary |
| Proof interface | `src/interfaces/ITaoRootStateVerifier.sol` | Transport/authentication seam |
| EVM policy | `src/lz/LeafTaoRootPolicy.sol` | netuid/runtime/listing checks |
| EVM adapter | `src/lz/LeafTaoRootAdapter.sol` | Authenticated snapshot storage + monotonicity + local freshness |
| Keeper | `keeper/tao/rootBasket.ts` | Bittensor observation/type seam |
| Tests | `test/lz/LeafTaoRootAdapter.t.sol` | Core snapshot/security invariants |
| Docs | `docs/TAO_ROOT_BASKET.md` | Full architecture + security boundary |

## Economic model encoded

```text
Root stake principal
        |
        +--> validator-specific basket
                  |
                  +--> beta entitlement
                  |
                  +--> realizable TAO quote
```

Do not collapse these into a single exchange-rate variable. Root Reborn describes the basket as validator-specific, with stake remaining on root and claims realizing a proportional basket slice back into TAO root stake.

## Official Bittensor references

- Root Reborn: https://preview.bittensor.com/docs/guides/root-reborn
- Beta tokens: https://www.bittensor.com/docs/concepts/beta-tokens
- Runtime APIs: https://github.com/latent-to/developer-docs/blob/main/docs/subtensor-api/runtime.md

## Release gate

Before this framework can back an actual hTAO listing, add and test:

1. authenticated Bittensor proof / bridge path;
2. exact coldkey + validator binding;
3. replay protection;
4. canonical basket holdings and realizable quote verification;
5. claim execution that matches Bittensor's native `claim-root-with-hotkey` semantics;
6. stale-proof and insolvent-state handling;
7. end-to-end fork/integration tests against a supported Bittensor runtime.

Until then, these contracts are deliberately non-production scaffolding.
