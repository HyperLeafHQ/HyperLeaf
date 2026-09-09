# hNEST Product Policy

## Decision

The current mainnet hNEST product continues to use the **existing deployed `NestVault`** at `0x4f6615761A772e10d7f802B1C29654ABD90fF30d`.

We are **not** migrating the live product to a new `NestVaultC1` contract. The deployed NestVault is an immutable legacy deployment, so adding a new function (or changing a constant) in this repository **cannot** change the already deployed contract.

Instead, hNEST is served **as a C1-style asset at the product layer** while retaining the existing protocol redemption path on-chain as a backstop.

## Why C1-style

The veNEST lock is ~26 weeks. Almost nobody will wait that long for protocol redeem — they would have staked NEST themselves. The product exit is therefore the secondary market.

## User-facing behavior

- hNEST remains a normal transferable ERC20.
- The primary exit is the secondary market: sell or otherwise transfer hNEST to a buyer who wants the underlying Nest position.
- The frontend / app must **not** expose a redeem, withdraw, or exit-to-NEST window for normal users.
- Product copy should emphasize the underlying lock, liquidity conditions, market price, and the fact that HyperLeaf does not guarantee an NAV floor or secondary-market buyer.
- The absence of a redeem button is a product-policy choice, not a claim that the contract lacks redemption functionality.

## Protocol-level behavior

The existing `NestVault.requestWithdraw(hNestAmount)` path remains deployed and callable directly on-chain. It is retained as a **manual / emergency / backend backstop** and must not be marketed as the preferred user journey.

Its existing operational constraints still apply:

- hNEST is burned when a redemption request is accepted;
- the request enters the existing withdrawal queue;
- liquidity may depend on the idle NEST buffer and keeper-driven veNEST detachment;
- HEV / Nest timing can make the practical exit substantially slower than a market sale.

Therefore the product can behave like C1 without changing the immutable live Vault.

## Two clocks (do not share)

Live HyperEVM, probed 2026-09-10:

| Clock | Value | What it gates |
| ----- | ----- | ------------- |
| **HEV `detachmentLockDuration()`** | **4 days** (`345600`) | `Voter.dettachFromManagedNFT`. Custody. We do not control HEV. |
| **Live NestVault `0x4f6615…` `DETACHMENT_LOCK_DURATION()`** | **4 days** (`345600`) | Keeper `dettachForLiquidity` only. Same as HEV. Immutable. |
| **Nest epoch** | **7 days**, Thursday 00:00 UTC | HYPE / NEST reward accounting. Keeper harvests 00:30 UTC. |
| **hNEST circulation gate** | `max(deposit + 8 days, epochEnd + 30 minutes)` | When a new deposit's hNEST is economically “epoch-settled” for secondary-market transfer. **Not** a dettach lock. |

`HNestCirculation.claimableAt(depositTs)` is the formula. Do **not** write `claimableAt = deposit + 8 days` alone, and do **not** fold 8 days into `dettachForLiquidity`.

At Day 4 the underlying veNEST is technically dettachable. hNEST from that deposit is still inside the circulation window until Day 8 / epoch settlement. That split is intentional: we do not use HEV's 4 days to prove a reward epoch has finished.

Live vault mints transferable hNEST on deposit and cannot be patched. The circulation gate is product/frontend (and any future wrap). `requestWithdraw` stays a hidden backstop.

## Detach (4 days, HEV custody)

- **Live + this source:** `DETACHMENT_LOCK_DURATION = 4 days`, matching HEV.
- **Tests:** 4d−1 reverts `DettachTooEarly`. Exactly 4d is the first legal dettach. 4d dettach is still before `HNestCirculation.claimableAt`.

## `ownerTransferVeNFT`

Repo source includes an owner-only veNEST custody transfer that **decrements `totalNestLocked`** by that NFT's principal + booked yield. Remaining hNEST is diluted unless matching supply is burned off-path.

This function **does not exist** on the already-deployed live vault. It cannot move mainnet test funds already sitting in `0x4f6615…`. Those funds stay in that vault; the C1 product layer is how users exit (secondary market). Any future vault replacement is a separate migration.

## Security and accounting posture

Keep: adapter freeze while live, bounded withdrawal processing, O(1) pending-withdraw accounting, zero-share redemption guard, HEV vault freeze while NFTs are deposited.

Do **not** revive NestVaultC1, depositGate, or a second vault as the current product.

## Frontend integration rule

For the live hNEST listing:

```text
Deposit NEST
    ↓
Existing mainnet NestVault
    ↓
hNEST
    ↓
Use / hold / LP / lend / trade
    ↓
Primary exit = secondary market (转让板 / DEX)

Direct NestVault.requestWithdraw
    ↑
Hidden from normal UI
Manual / emergency / backend backstop only
```

The frontend may still surface factual risk information such as the existence of a contract-level redemption backstop, but it should not create a prominent redeem CTA or imply that protocol redemption is the normal exit.

## Deployment rule

Do not deploy `NestVaultC1` for the current hNEST product. Do not tell grok bot to replace the live vault. Any future Vault replacement must be treated as a separate migration with explicit backing movement, hNEST supply migration, ownership transfer, user communication, and audit review.
