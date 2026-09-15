# Remote-claim OTC (generic)

Not a Leaf wrapper and not a treasury desk. The product is:

```
seller locks token on the source chain
        ↓
HyperEVM claim minted 1:1 (same decimals)
        ↓
Leaf Market: claim ↔ HyperEVM USDC   (fillLocal, same as hNEST)
        ↓
buyer holds the claim, redeems back to the source chain
```

Premium is the Leaf Market price. Protocol does not bid, does not hold inventory, does not promise 1:1 HyperEVM USDC.

## First listing (practice): Arc USDC

- Source: Arc native USDC (mainnet address TBD at public launch).
- Claim: `hArcUSDC` on HyperEVM, 6 decimals.
- Want: Circle USDC on HyperEVM `0xb88339CB7199b77E23DB6E890353E22632Ba630f`.
- Status: **code kernel only**. Do not deploy until:
  1. Arc public RPC + USDC address are official.
  2. There is still no cheap 1:1 CCTP/bridge Arc ↔ HyperEVM (that kills the premium).
  3. The mailbox is a real LZ (or equivalent) adapter, **not** `OtcSameChainMailbox`.

Same-chain mailbox is for tests. Using it on two live chains would mint without a lock.

## What this is not

- Not Luna's Base USDC ↔ Arc USDC HTLC desk (Unstable / ArcExit already do that).
- Not PreMarketFactory (VAR points, same-chain USDM escrow).
- Not the LST wrap stack (no inner ceiling, no rate feed, no Rewarder).

## Contracts

| Contract | Chain | Role |
| --- | --- | --- |
| `OtcRemoteLock` | source | Pulls underlying, `totalLocked` 1:1 |
| `OtcClaim` | HyperEVM | Listable ERC-20; `redeem` burns and releases source |
| `IOtcMailbox` | both | `notifyDeposit` / `notifyRedeem` |
| `OtcSameChainMailbox` | tests | Immediate mint/release |
| LeafClaimEscrow | HyperEVM | Existing Leaf Market. `setMarket(claim, hevmUsdc, 0, true)` |

Later corridors (any OTC where inventory is on another chain and cash is on HyperEVM) reuse lock + claim + a new mailbox. Do not fork Leaf Market.

## Fee

Wrap layer: 0. Revenue is Leaf Market occupancy / incentive rules already live. Do not add a second fee on deposit.
