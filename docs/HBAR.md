# HBAR / HBARX — later (2026-09-10)

Do **not** wrap raw HBAR. Hedera native stake is account-level, **no lock**, no transferable receipt.

Wrap **HBARX only** (Stader LST). Official:

- Token ID `0.0.834116`
- EVM `0x00000000000000000000000000000000000cba44`
- 8 decimals, HTS `FUNGIBLE_COMMON`
- Unstake **1 day** stays on Stader. Lockbox never unstakes (`requestWithdraw` / `unstake` forbidden).
- RateKind.None until StakeManager is pinned. 8-dec → 18-dec `SHARE_SCALE = 1e10`.

LayerZero Hedera **eid 30316**. Endpoint V2 live. ULN/DVN in `LayerZeroAddresses` / `LeafSecurity.hederaOptionalDvns()`.

## Adapter

`LeafOFTAdapter._pull` / `associateInner()` call `LeafHts.associateSelf` on chain 295/296. Off Hedera: no-op. Fund tiny HBAR on the lockbox before first wrap (HTS associate fee).

`productionEvm=false`. `MainnetBatches` → `NotThisBatch`. Flip both only after a Hedera dust wrap.

Never BNBx (sunset) ≠ this product.
