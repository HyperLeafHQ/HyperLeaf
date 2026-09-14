# NestVault C1 / hNEST — Mainnet Deployment Checklist

**Status:** Mandatory before opening deposits. Targets `NestVaultC1` (`feat/nest-c1`).
**Updated:** 2026-09-14 — rewritten for C1. The v1 vault `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` is abandoned (test TVL). Do not patch it, do not deploy it, do not point the gate at it.

C1 has **no redeem, no idle buffer, no `recordCompound`, no `topUpIdle`** — v1 idle parameters (`idleDepositBps`, `minIdleNest`) do not exist here. Exit is Leaf Market; circulation is EpochHNestGate (8d).

## Confirmed production roles (four-way split)

| Role | Address | Notes |
|------|---------|--------|
| **Owner** | `0x24458f0bC44C4607172d1151Cd938012Be33156e` | User-controlled EOA. Ownable2Step: deploy → `transferOwnership` → Owner `acceptOwnership`. |
| **Guardian** | `0x12dF4528E7Cc3db07A509c966c6405b69A25Ef2e` | User's **other** EOA (**≠ Owner**). **Pause only** (cannot unpause / setters / depositsEnabled). May intentionally be `address(0)` (pause role disabled) — decide explicitly at deploy, see ops note (i). |
| **Keeper** | `0xc321DD8826a30D8a6D973821a3dB7b8090955887` | Hyperleaf hot wallet. harvest / bookVerifiedYield / settle only. **Never Owner or Guardian.** |
| **feeRecipient** | `0x76c8c4586F0a3d335CF7192eBbB4FE6Ed5Af3804` | Protocol fee sink (1% HYPE fee + yield fee shares). Separate from Keeper. |
| **Deployer** | same hot wallet as Keeper for deploy txs only | Deploy + initial config, then hand Owner to user. **NEVER leave deployer as Owner/Guardian.** |

Testnet may collapse roles for drills. **Copying testnet role collapse to mainnet is forbidden.**

## Deployment flow (C1)

> **Nonce race rule:** never use the deployer key for any other transaction between simulation and broadcast — an extra tx shifts the nonce and invalidates the predicted vault address (`new HNest(predictedVault)` and the `vault address mismatch` assert depend on it).

1. [ ] **(Optional) Pre-deploy HNest** if gas is tight (HyperEVM block gasLimit = 3M): `new HNest(predictedVault)` requires nonce prediction — otherwise let `script/DeployNestVaultC1.s.sol` deploy it inline (it does the nonce math). A pre-deployed HNest must target `computeCreateAddress(deployer, n0 + 1)` under the **same account and nonce base `n0`** the deploy script will see at broadcast time (the script deploys the vault at `n0 + 1` when `HNEST` is set, `n0 + 2` otherwise) — otherwise the vault constructor reverts `InvalidHNest`.
2. [ ] `forge script script/DeployNestVaultC1.s.sol --rpc-url hyperevm --broadcast` with env: `PRIVATE_KEY`, `FEE_RECIPIENT`, `KEEPER`, optional `GUARDIAN`, `DEPOSIT_CAP`, `HNEST` (pre-deployed), `HYPE_TOKEN` (defaults to WHYPE `0x5555…5555`), `NEST_TOKEN`, `VE_NEST`, HEV wiring overrides. Script enforces `chainid == 999`, deploys `HevAdapter → HNest → NestVaultC1` with nonce prediction, wires `adapter.setVault`, asserts `hNest.vault() == vault` and the pinned merkle `0x33afCe…0905`, and rejects env-overridden contract addresses with no code.
3. [ ] **Post-broadcast on-chain readback** (script output / simulation is not enough — read the chain directly):
   ```
   cast call $VAULT "hNest()(address)" --rpc-url hyperevm          # == deployed HNest
   cast call $HNEST "vault()(address)" --rpc-url hyperevm          # == $VAULT
   cast call $ADAPTER "vault()(address)" --rpc-url hyperevm        # == $VAULT
   cast call $VAULT "merkleAirdrop()(address)" --rpc-url hyperevm  # == 0x33afCe556508A39181a0609288c3E93611a00905
   cast call $VAULT "depositsEnabled()(bool)" --rpc-url hyperevm   # == false
   ```
   All five must match expectations before continuing.
4. [ ] Verify script output: `depositsEnabled == false`, `depositGate == address(0)`.
5. [ ] Deploy the gate: `VAULT_ADDRESS=<vault> forge script script/DeployEpochHNestGate.s.sol --rpc-url hyperevm --broadcast` (script refuses an empty `VAULT_ADDRESS` or one with no code). Owner of the gate must `acceptOwnership`.
6. [ ] Owner: `vault.setDepositGate(gate)` — **one-shot**, verify the gate address twice before calling (ops note e).
7. [ ] Readback verification: `gate.vault() == vault` **and** `vault.depositGate() == gate`.
8. [ ] Ownable2Step handoff to Owner `0x24458f0b…156e` complete (`acceptOwnership`).
9. [ ] Confirm roles: `setGuardian` / `setKeeper` / `setFeeRecipient` per the table above (constructor args already set them; verify on-chain).
10. [ ] Confirm `depositsEnabled == false` until step 11.
11. [ ] Smoke checks (small gated deposit via gate, `settleInboundHype`, `bookVerifiedYield(0, n)`) → only then Owner `setDepositsEnabled(true)`.

## Security gates already in code (C1)

| Gate | Behavior |
|------|----------|
| Deposits | `deposit()` gate-only (`OnlyDepositGate`); `depositGate` set once (`DepositGateFrozen`) |
| Redeem | none — permanent lock, `withPermanentLock=true` |
| HYPE fee | `settleInboundHype` takes `feeBps` (max 500) before crediting holders |
| Yield cap | `bookVerifiedYield` capped at `MAX_YIELD_BOOK_BPS` (10%) of `totalNestLocked` per week, cumulative across paginated calls |
| Pause | freezes deposits only; merkle claim / settle stay live |
| NFT rescue | `recoverERC721` blocks registered veNEST positions (`ProtectedVeNft`) |

## Ops notes (read before operating)

- **(a) Vote-window deposit reverts.** Deposits revert during Nest Voter distribution windows (first/last hour of each weekly epoch, ~Thursday 00:00 UTC boundaries). Schedule keeper/gate transactions around them; a reverting deposit is expected behavior, not an incident.
- **(b) Third-party Merkle claims.** If a third party calls `Merkle.claim` directly for the vault's leaf, `claimMerkle` will later revert `AlreadyClaimed` for the same cumulative amount. Fall back to permissionless `settleInboundHype()` — the WHYPE is already in the vault and settles the same way.
- **(c) Proof rotation.** The merkle root rotates every Thursday 00:00 UTC. Refetch the proof after each rotation: `GET https://app.usenest.xyz/api/liveprograms/api/hype-distribution/merkle-proof/{vault}`. `amount` is cumulative — use the latest value.
- **(d) depositCap includes booked yield.** `depositCap` is measured against `totalNestLocked`, which grows when `bookVerifiedYield` books HEV share growth. A cap set against principal only will bite earlier than expected.
- **(e) setDepositGate is one-shot.** It cannot be changed or re-called. Verify the gate address twice (and `gate.vault() == vault`) before calling; a mistake bricks deposits permanently.
- **(f) Keeper pagination.** `veNFTIds` grows by one per deposit. Once it approaches **~150**, keepers must switch from `bookVerifiedYield()` to paginated `bookVerifiedYield(start, end)` — the full sweep bricks around ~200-300 NFTs under HyperEVM's 3M small-block gas limit. Paginated or not, the keeper MUST cover the full `[0, totalVeNFTs())` range at least once per epoch — the contract does not enforce full coverage; skipped NFTs defer write-downs and leave the share price stale. Note the weekly cap base (`totalNestLocked`) grows as each paginated call books, so under pagination the effective weekly cap is ≈10.5-11% of week-start `totalNestLocked`, not exactly 10% (accepted, keeper-only).
- **(g) setFee has no timelock.** Fee changes take effect on the next settle. Owner ops policy: announce fee changes ahead of weekly settlements; never change the fee between a merkle root rotation and its settlement.
- **(h) No ERC20 rescue.** There is intentionally no `recoverERC20`. Any non-WHYPE token, or NEST sent directly to the vault (not via `deposit`), is stranded by design. Donations of WHYPE are treated as campaign yield (fee applies).
- **(i) Guardian may be address(0).** This disables the pause role entirely. Decide explicitly at deploy time; `setGuardian` can install one later (Owner-only).

## Post-deploy monitors

- `Deposited`, `InboundHypeSettled`, `MerkleClaimed` (received delta, not cumulative), `YieldBooked` / `YieldWrittenDown`, `HarvestExecuted` (real gross/fee)
- `Paused` / `Unpaused`, `DepositsEnabledUpdated`, `DepositGateUpdated`, `FeeUpdated`, `FeeRecipientUpdated`
- `hypeToken.balanceOf(vault) >= hypeAccounted` invariant
- `veNFTIds.length` vs the ~150 keeper-pagination threshold
- Role addresses remain the four-way split above
