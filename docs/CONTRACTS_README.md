# hNEST / NestVault — contracts notes

`forge test`; addresses in `src/config/HyperEVMAddresses.sol` and `deployments/`.

## Yield rails (must match code)

1. **Nest/HEV automation** — vault locks via `createLockFor` + HEV attach; Nest may compound under Nest rules.
2. **`recordCompound` disabled** — HyperLeaf will **not** book unbacked `totalNestLocked` increases. Do **not** claim hNEST NAV auto-rises until a verifiable path ships.
3. **Nest public HYPE Spring share** — Nest-protocol airdrop/eligibility; not a HyperLeaf built-in claim.
4. MEGAHYPE — not live; do not invent.

## Risks

HEV / VR source gaps; exit delays (idle + dettach ~26w worst path); hNEST secondary discount; role custody; feeBps. Security status: **internal review only**, not third-party audit.

## Pause / guardian

- Guardian or owner can `pause()` (blocks deposit + requestWithdraw).
- Only owner `unpause()`.
- See `docs/DEPLOYMENT_CHECKLIST.md` for mainnet roles + idle + topUp budget.
