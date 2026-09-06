# hNEST / NestVault — contracts notes

`forge test`; addresses in `src/config/HyperEVMAddresses.sol` and `deployments/`.

## Yield rails (product wording)

1. **Auto-compound into share value** — Nest/HEV compounding increases the NEST backing per hNEST (NAV / share price). This is the primary HyperLeaf accrual. Do **not** describe it as a user “auto-reinvest claim” button.
2. **Nest public HYPE Spring share** — any liquid HYPE from Nest’s public HYPE Spring is Nest-protocol airdrop/eligibility for the vault’s locks; claim UX/ABI lives on Nest until HyperLeaf wires a vault claim. Do **not** promise “claim HYPE anytime in HyperLeaf UI”.
3. MEGAHYPE — not live; do not invent.

## Risks

HEV / VR source gaps; exit delays (idle + dettach ~26w worst path); hNEST secondary discount; role custody; feeBps.

## Pause / guardian

- Guardian or owner can `pause()` (blocks deposit + requestWithdraw).
- Only owner `unpause()`.
- See `docs/DEPLOYMENT_CHECKLIST.md` for mainnet roles + idle + topUp budget.
