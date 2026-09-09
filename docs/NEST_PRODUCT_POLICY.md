# hNEST Product Policy

## Decision

The current mainnet hNEST product continues to use the **existing deployed `NestVault`** at `0x4f6615761A772e10d7f802B1C29654ABD90fF30d`.

We are **not** migrating the live product to a new `NestVaultC1` contract. The deployed NestVault is an immutable legacy deployment, so adding a new function to the repository source cannot change the already deployed contract.

Instead, hNEST is served **as a C1-style asset at the product layer** while retaining the existing protocol redemption path on-chain as a backstop.

## User-facing behavior

- hNEST remains a normal transferable ERC20.
- The primary exit is the secondary market: sell or otherwise transfer hNEST to a buyer who wants the underlying Nest position.
- The frontend / app should **not expose a redeem, withdraw, or exit-to-NEST window** for normal users.
- Product copy should emphasize the underlying lock, liquidity conditions, market price, and the fact that HyperLeaf does not guarantee an NAV floor or secondary-market buyer.
- The absence of a redeem button is a product-policy choice, not a claim that the contract lacks redemption functionality.

## Protocol-level behavior

The existing `NestVault.requestWithdraw(hNestAmount)` path remains deployed and callable directly on-chain. It is retained as a **manual / emergency / backstop exit path** and should not be marketed as the preferred user journey.

Its existing operational constraints still apply:

- hNEST is burned when a redemption request is accepted;
- the request enters the existing withdrawal queue;
- liquidity may depend on the idle NEST buffer and keeper-driven veNEST detachment;
- HEV / Nest timing can make the practical exit substantially slower than a market sale.

Therefore the product can behave like C1 without changing the immutable live Vault.

## Security and accounting posture

The security fixes already landed on the current branch remain applicable to the old Vault implementation, including adapter-state hardening, bounded withdrawal processing, O(1) pending-withdraw accounting, and the zero-share redemption guard.

The branch may contain development-only C1 experiments, but they are **not part of the mainnet hNEST deployment path** and should not be used as the basis for current frontend or deployment decisions.

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
Primary exit = secondary market

Direct NestVault redemption
    ↑
Hidden from normal UI
Manual / emergency backstop only
```

The frontend may still surface factual risk information such as the existence of a contract-level redemption backstop, but it should not create a prominent redeem CTA or imply that protocol redemption is the normal exit.

## Deployment rule

Do not deploy `NestVaultC1` for the current hNEST product. Any future Vault replacement must be treated as a separate migration with explicit backing movement, hNEST supply migration, ownership transfer, user communication, and audit review.
