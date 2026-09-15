# Spot OTC — remote claim + Leaf Market

Not a Leaf wrapper and not a treasury desk. Spot OTC is:

```
seller locks token on the source chain
        ↓  mailbox (LZ)
HyperEVM claim minted 1:1 (same decimals)
        ↓
Leaf Market fillLocal: claim ↔ HyperEVM USDC
        ↓
buyer holds the claim, redeems back to the source chain
```

Premium is the Leaf Market ask. Protocol does not bid, does not hold inventory, does not promise 1 HyperEVM USDC per 1 source unit.

Pre-market (VAR) is a different product: same-chain USDM escrow + future official token. Do not reuse PreMarketFactory here.

## First listing (practice): Arc USDC

- Source: Arc native USDC (mainnet address TBD).
- Claim: `hArcUSDC` on HyperEVM, 6 decimals.
- Want: Circle USDC `0xb88339CB7199b77E23DB6E890353E22632Ba630f`.
- **Do not deploy** until public Arc RPC exists, CCTP Arc↔HyperEVM is not 1:1, and `OtcLzMailbox` peers are frozen.

`OtcSameChainMailbox` is tests only. Two live chains + same-chain mailbox would mint without a lock.

## Contracts

| Contract | Chain | Role |
| --- | --- | --- |
| `OtcRemoteLock` | source | Pulls underlying, `totalLocked` 1:1, optional `maxLocked` |
| `OtcClaim` | HyperEVM | Listable ERC-20; `redeem` burns |
| `OtcLzMailbox` | both | `OP_MINT` / `OP_RELEASE` over LZ |
| `OtcSameChainMailbox` | tests | Immediate mint/release |
| LeafClaimEscrow | HyperEVM | `setMarket(claim, hevmUsdc, 0, true)` |

Guardian can pause lock / claim / LZ mailbox. Owner unpauses. Mailbox, lock, and claim ends are one-shot.

Later corridors swap the lock token + LZ EIDs. Do not fork Leaf Market.

## Fee

Wrap layer: 0. Leaf Market already takes the 1% buyer incentive and occupancy rules. Do not add a deposit fee.

## LZ in-flight

`deposit` credits `totalLocked` before dest mint. If dest `lzReceive` never runs, inventory sits until the executor retries. Do not skip the nonce. Same on redeem: burn first, source `release` on message.
