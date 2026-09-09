# Nest: C1 transition and retained audit findings

## Decision

Nest is being moved to a C1-style non-redeemable design.

The reason is product-level rather than a claim that the existing redemption queue is exploitable. hNEST is intended to be the liquid, composable financial form of the Nest staking position. Native redemption with a multi-month unlock window does not add meaningful user value versus staking NEST directly and creates an unnecessary mapping between fungible hNEST balances and indivisible veNEST NFTs.

Under C1:

- Users deposit NEST and receive transferable hNEST.
- hNEST is a normal ERC20 and may be transferred or traded on a secondary market.
- There is no user-facing NEST redemption.
- There is no withdrawal queue, idle redemption buffer, or keeper-driven liquidity detachment.
- 100% of each new deposit is locked into a veNEST NFT.
- veNEST custody operations remain owner-only for migration/emergency handling.

## Retained audit findings from the prior redeemable design

### Adapter live-swap state split
`NestVault.setHevAdapter()` could replace the adapter after deposits while the Vault retained `inHev[tokenId]` state in the old adapter. The replacement adapter had no corresponding `deposited[tokenId]` records, so later detachment could revert and make redemption liquidity unavailable.

Status: mitigated in C1 by making adapter configuration immutable once `totalNestLocked != 0`. C1 does not have a keeper/user redemption detachment path.

### Mutable adapter vault
`HevAdapter.setVault()` could change the authorized Vault while NFTs were already recorded as deposited, creating a split-brain authorization state.

Status: mitigated by rejecting vault changes while the adapter has deposited NFTs. See `HevAdapter.depositedCount` / `VaultChangeWhileDeposited`.

### O(n) withdrawal processing
The prior redeemable design scanned veNFTs and withdrawal requests during keeper processing. At sufficient scale this could turn keeper operations into a gas availability bottleneck.

Status: the C1 Vault removes the user withdrawal queue and does not detach NFTs for liquidity. The old queue implementation remains only in the legacy `NestVault` contract.

### Small redemption rounding / NFT granularity
The redeemable design mapped hNEST to NEST by `hNestAmount * totalNestLocked / totalSupply`, then burned hNEST and queued the resulting NEST amount. Very small redemptions could round down to zero, and even ordinary small redemptions could require detaching an entire veNFT to create liquidity for a small user claim.

Status: eliminated from the C1 user path because redemption is disabled. veNFT merge/split remains an internal custody optimization for a future migration/strategy layer.

### Deposit-cap upward movement
An owner can raise `depositCap` or set it to zero. This is retained as an operational configuration rather than treated as a blocking security defect because the current cap is a rollout control and the protocol roadmap explicitly requires future cap increases after claim-function testing.

## C1 administrative custody

The C1 Vault exposes owner-only operations for:

- detaching a Vault-owned veNFT through the configured HEV adapter;
- transferring a detached veNFT for migration/custody;
- withdrawing a detached veNFT's underlying NEST;
- merging two detached veNFTs.

These functions are intentionally privileged. They must be treated as migration/emergency powers because transferring or withdrawing a backing NFT can change the backing of outstanding hNEST.

The C1 migration should therefore be accompanied by a protocol-level plan for retiring or swapping any old hNEST before backing is moved out of the Vault.

## EpochGate relationship

`EpochHNestGate` is an issuance/reward-timing layer, not a redemption layer. A user deposits NEST into the Gate, the Gate calls the C1 Vault, and the resulting hNEST is held by the Gate until the Nest epoch is finalized. After claim, the user receives ordinary transferable hNEST.

The Gate must not be treated as a beneficiary of the C1 Vault's unrelated residual-HYPE accounting without an explicit accounting bridge.
