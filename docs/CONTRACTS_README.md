# hNEST / NestVault — contracts notes

`forge test`; addresses in `src/config/HyperEVMAddresses.sol` and `deployments/`.

For the complete economic and security model, read [`NEST_ARCHITECTURE.md`](NEST_ARCHITECTURE.md) first. This page is intentionally the short contract reference.

## Yield rails (must match code)

1. **Nest/HEV automation** — vault locks via `createLockFor` + HEV attach; Nest may compound under Nest rules.
2. **`recordCompound` disabled** — HyperLeaf will **not** book unbacked `totalNestLocked` increases. Do **not** claim hNEST NAV auto-rises until a verifiable path ships.
3. **Nest public HYPE Spring share** — Nest-protocol airdrop/eligibility; not a HyperLeaf built-in claim.
4. MEGAHYPE — not live; do not invent.

## Product architecture

```text
NEST → NestVault → veNEST / HEV → hNEST
                               ↓
                       Leaf Market / NEST
                               ↑
                     protocol redeem backstop
```

The current hNEST product is C1-style at the product layer: normal exits use the secondary market because the underlying veNEST position is long-duration. The existing live NestVault remains the protocol redemption backstop.

## Three clocks

- **4 days** — HEV detachment custody window.
- **7 days** — Nest economic epoch, Thursday 00:00 UTC.
- **8 days + epoch settlement** — Gate circulation condition for deposits that use `EpochHNestGate`.

These clocks are intentionally separate. See `NEST_ARCHITECTURE.md` and `NEST_PRODUCT_POLICY.md`.

## Risks

HEV / VR source gaps; long exit delays (detachment can lead to a ~26w unlock path); hNEST secondary discount; role custody; fee governance; upstream ABI changes; live-vault Gate bypass; reward-accounting ambiguity. Security status: **internal review only**, not a third-party audit.

## Pause / guardian

- Guardian or owner can `pause()` (blocks deposit + requestWithdraw).
- Only owner `unpause()`.
- See `docs/DEPLOYMENT_CHECKLIST.md` for mainnet roles + idle + topUp budget.

## Accounting rules

- Never raise hNEST liability without verifiable backing.
- Do not treat Nest-side locked NEST rewards as liquid HYPE.
- Do not promise a secondary-market buyer or fixed NAV exit.
- Gate deposits are tranche-based; a later deposit must not delay an earlier tranche.
- Fee configuration is snapshotted per Gate epoch.
