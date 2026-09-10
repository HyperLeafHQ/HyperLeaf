# hsSUI — later, after hJitoSOL (2026-09-11)

Wrap **SpringSui sSUI** only. Instant LST. User who wants SUI: unwrap hsSUI → sSUI, then SpringSui.

| | |
| --- | --- |
| Coin | `0x83556891f4a0f233ce7b05cfe7f957d4020492a34f5405b2cb9377d060bef4bf::spring_sui::SPRING_SUI` |
| Decimals | 9. Dest `LeafOFT` 18. `shares = atoms * 1e9` |
| LZ | eid **30378** → 30367. Testnet 40378. Peer on EVM = **Sui OFT package id**, not object id |
| DVN | Labs + Horizen + Canary are on Sui mainnet. Never Nethermind |
| Source | **Move lockbox**, not `LeafOFTAdapter` |

Do **not** wrap: raw `0x2::sui::SUI`, haSUI, afSUI, vSUI, AlphaFi stSUI. Those are other receipts or cooldown LSTs.

Do **not** unstake sSUI → SUI from the lockbox. Instant redeem is SpringSui’s; we return sSUI.

Do **not** advertise 1.32% / wallet APR. Yield is sSUI/SUI rate, 1% retain once the Move box exists (same math as hJitoSOL).

Confirmations for Sui ULN: **not pinned** until we read the live default. Do not copy Solana 32.

`productionEvm=false`. `NotThisBatch`.
