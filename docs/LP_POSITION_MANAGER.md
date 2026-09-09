# Generic LP Position Management

HyperLeaf can manage productive LP positions without making the core protocol depend on a specific DEX, NFT format, or CLMM implementation.

## Architecture

```text
                 ┌──────────────────────────────┐
                 │         LPPositionManager     │
                 │ policy / limits / keeper auth │
                 └──────────────┬───────────────┘
                                │
                         ILPPositionAdapter
                                │
          ┌─────────────────────┼─────────────────────┐
          ▼                     ▼                     ▼
    V3 / CLMM NFT          HyperEVM DEX          future venue
    adapter                adapter               adapter

off-chain:

LPKeeper ──reads──> positionState()
   │
   ├── strategy decides whether to rebalance
   │
   ├── constructs bounded RebalanceParams
   │
   └── simulate → executeRebalance()
```

The keeper decides *when* and *where* to move a position. The manager decides *whether the requested action is permitted*. The adapter decides *how the venue actually performs it*.

## Why this is generic

The manager deliberately does not know:

- DEX or router identity;
- NFT position IDs;
- pool fee tiers;
- CLMM math;
- quote/oracle implementation;
- whether a position is represented by an NFT, account slot, or other venue object.

A position is identified by a HyperLeaf-local `bytes32 positionId`; the adapter maps that identifier to the venue-specific state.

## Rebalance safety boundary

Every keeper action is bounded by:

1. configured keeper address;
2. position active/pause state;
3. manager-wide pause;
4. per-position cooldown;
5. transaction deadline;
6. stored maximum token-in budget;
7. stored maximum slippage policy;
8. adapter-reported spent amounts not exceeding the requested budgets;
9. adapter-reported outputs meeting the requested minimums.

Exact price impact, quote validity, pool-state freshness, tick spacing rules, and router calldata remain adapter responsibilities.

## Recommended adapter contract

Each production adapter should:

- hard-bind its manager address;
- validate the venue position belongs to the configured HyperLeaf listing;
- reject arbitrary position IDs / token IDs;
- enforce the passed `deadline`, tick/range semantics, and minimum outputs;
- return accounting deltas measured from the adapter's actual token balances or trusted venue receipts;
- never mint a second economic claim for the same underlying LP position;
- emit venue-specific execution events with enough information for off-chain accounting.

## Keeper model

`keeper/lp/runner.ts` is intentionally small. It can be reused with different strategies:

- `RecenterRangeStrategy` for concentrated liquidity;
- fee-harvest strategy;
- volatility-aware range strategy;
- inventory-targeting strategy;
- venue-specific strategies implemented outside the core runner.

The default entrypoint `keeper/lp-keeper.ts` is a one-position reference process and starts in dry-run mode unless `LP_KEEPER_DRY_RUN=false` is explicitly set.

## Production hardening before mainnet

This is a reusable execution framework, not a production DEX adapter. Before a real listing is enabled, add venue-specific controls and tests for:

- stale pool state / price movement between quote and inclusion;
- exact swap slippage and price-limit semantics;
- token decimal normalization;
- fee collection accounting;
- stuck or burned LP NFTs;
- adapter upgrade authority;
- position ownership and custody invariants;
- keeper key rotation and transaction replacement;
- fork tests against the actual venue.

The existing HyperLeaf architecture treats asset/listing risk as isolated. LP management should follow the same rule: one adapter/listing failure must not silently alter another position's policy or backing.
