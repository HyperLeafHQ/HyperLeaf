# Stable Asset Protection Framework — Index

## Core

- `src/StableAssetController.sol` — normalized health states, policy gates, and listing registry.
- `src/interfaces/IStableAssetAdapter.sol` — venue-specific peg, exit-liquidity, and primary-redeem surface.
- `src/interfaces/IStableExitBuffer.sol` — optional bounded protocol exit-buffer surface.

## Tests

- `test/mocks/MockStableAssetAdapter.sol` — deterministic adapter for policy tests.
- `test/StableAssetController.t.sol` — healthy, stale, low-coverage, depeg, and pause behavior.

## Docs

- `docs/STABLE_ASSET_FRAMEWORK.md` — architecture, invariants, Leaf Market integration, and rollout rules.

## Relationship to Leaf Market

Leaf Market remains the secondary exit venue. This framework is a protection / policy layer and does not create a second market, AMM, or protocol-owned standing bid.

## Next integrations

1. PYUSD / USDG — issuer-backed reserve and direct redemption adapters.
2. Aave USDC — utilization / immediate liquidity adapter.
3. Morpho DAI — ERC-4626 share-price + vault unwind adapter.
4. Bitway USDT / HertzFlow USD1 — venue-specific redemption and liquidity adapters after evidence review.

Each integration should ship separately with its own failure-mode tests and on-chain verification notes.
