# Nest: C1 transition and retained audit findings

## Decision

Nest is moving to a C1-style non-redeemable design.

The reason is product-level rather than a claim that the existing redemption queue is exploitable. hNEST is intended to be the liquid, composable financial form of the Nest staking position. Native redemption with a multi-month unlock window does not add meaningful user value versus staking NEST directly and creates an unnecessary mapping between fungible hNEST balances and indivisible veNEST NFTs.

Under C1:

- Users deposit NEST and receive transferable hNEST.
- hNEST is a normal ERC20 and may be transferred or traded on a secondary market.
- There is no user-facing NEST redemption.
- There is no withdrawal queue, idle redemption buffer, or keeper-driven liquidity detachment.
- 100% of every new deposit is locked into a veNEST NFT.
- veNEST custody operations remain owner-only for migration/emergency handling.

## Retained audit findings from the prior redeemable design

### Adapter live-swap state split
The prior `setHevAdapter()` path could replace the adapter after deposits while the Vault retained `inHev[tokenId]` state associated with the old adapter. The replacement adapter had no corresponding `deposited[tokenId]` records, so later detachment could revert and make redemption liquidity unavailable.

Status: mitigated in C1 by making adapter configuration immutable once `totalNestLocked != 0`. C1 has no keeper/user redemption detachment path.

### Mutable adapter vault
The adapter's `setVault()` could change the authorized Vault while NFTs were already recorded as deposited, creating a split-brain authorization state.

Status: mitigated by rejecting vault changes while the adapter has deposited NFTs (`depositedCount != 0`).

### O(n) withdrawal processing
The prior redeemable design scanned veNFTs and withdrawal requests during keeper processing. At sufficient scale this could turn keeper operations into a gas availability bottleneck.

Status: removed from the C1 user product path. C1 has no withdrawal queue and no keeper-driven liquidity detachment.

### Small redemption rounding / NFT granularity
The prior redeemable design converted hNEST to NEST with `hNestAmount * totalNestLocked / totalSupply`, burned hNEST, and queued the result. Very small redemptions could round to zero; ordinary small redemptions could also require detaching a whole veNFT to create liquidity for a small claim.

Status: eliminated from the C1 user path because redemption is disabled. veNEST merge/split remains an internal strategy capability, not a user redemption mechanism.

### Deposit-cap upward movement
An owner can raise `depositCap` or set it to zero. This is retained as an operational configuration rather than a blocking security defect because the current cap is a rollout control and the protocol roadmap requires future cap increases after claim-function testing.

Status: downgraded to configuration risk; no freeze is imposed in the C1 implementation.

## C1 administrative custody

`NestVaultC1` retains only owner-only veNEST custody operations needed for migration/emergency handling:

- `ownerDetachVeNFT` — detach a Vault-owned NFT through the configured HEV adapter;
- `ownerTransferVeNFT` — transfer a detached NFT to a migration/custody recipient;
- `ownerWithdrawVeNFT` — withdraw the underlying NEST from a detached NFT.

These functions intentionally remain privileged. Transferring or withdrawing backing while hNEST remains outstanding can change the collateralization of hNEST, so these paths are not part of normal protocol operation and should only be used under an explicit migration/emergency plan.

## EpochGate relationship

`EpochHNestGate` is an issuance/reward-timing layer, not a redemption layer. A user deposits NEST into the Gate, the Gate calls the C1 Vault, and the resulting hNEST is held by the Gate until the Nest epoch is finalized. After claim, the user receives ordinary transferable hNEST.

The Gate must not be treated as a beneficiary of the C1 Vault's unrelated residual-HYPE accounting without an explicit accounting bridge.
