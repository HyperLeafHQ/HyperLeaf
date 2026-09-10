# HBAR / HBARX — later (2026-09-10)

Do **not** wrap raw HBAR. Hedera native stake is account-level, **no lock**, no transferable receipt.

Wrap **HBARX only** (Stader LST, Hedera Foundation–backed). Official:

- Token ID `0.0.834116`
- EVM `0x00000000000000000000000000000000000cba44`
- 8 decimals, HTS `FUNGIBLE_COMMON`
- Mirror supply ≈ **2.85e16** (284.96M HBARX)
- Unstake **1 day** stays on Stader. Lockbox never unstakes.
- Stader takes **12%** of staking rewards (docs updated 2026-08-30).
- Rate = pool HBAR / HBARX supply. Rate is **not** on the token; do not set `RateKind` until StakeManager is pinned.

JSON-RPC: `symbol=HBARX`. Bytecode 147 (HTS facade). HyperEVM empty.

LayerZero Hedera **eid 30316** (USDT0 docs + LZ metadata). Endpoint V2 is live.

## Adapter gap

HTS requires **token associate** before `transferFrom`. `LeafOFTAdapter` does not associate. Do not deploy until the lockbox associates `0.0.834116` (constructor or first wrap). 8-dec path exists (hLBTC). Forbidden: Stader `requestWithdraw` / unstake.

`NotThisBatch`. After current EVM batches. Never BNBx (sunset) ≠ this product.
