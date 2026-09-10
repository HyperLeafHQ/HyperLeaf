# hstATOM — no EVM LST, Cosmos/IBC later

Verified 2026-09-10. Eval notes are not a source.

## Gate 0 — is there an EVM ATOM LST?

**No canonical one.** Do not wrap anything on Ethereum / Base / HyperEVM as “stATOM”.

| Candidate | Verdict |
| --- | --- |
| **Stride stATOM** | Canonical LST. Lives on **Stride** (`stuatom`). IBC around Cosmos. Not an ERC-20 we can `LeafOFTAdapter`. |
| Axelar `stATOM` on ETH/BSC/etc. | Bridged copy of Stride stATOM. Third-party wrapper. Same class as wrapping axlATOM: **spot of a bridge**, not the LST. |
| pSTAKE **ERC-20 stkATOM** | Officially deprecated. Migration closed **31 Dec 2025**. “Cease to be functional.” |
| Evmos ERC-20 stATOM `0xB512…536D` | Evmos **shut down May 2025**. Dead chain. |
| Drop dATOM / Quicksilver qATOM | Cosmos-native, not EVM. |

HyperEVM has no official stATOM. That would have been a reason **to** list — except the inner is not on an EVM we already speak.

## What we would wrap (when the lockbox exists)

Stride **stATOM**, on Stride, via IBC custody. Never ATOM, never axl-stATOM, never dead stkATOM.

Yield is the stATOM / ATOM redemption rate (non-rebasing). Same 1% skim class as JitoSOL / sPOL. Unbond on Cosmos Hub is **~21 days**; Stride redeem follows that. Lockbox **never** undelegate / redeem-to-ATOM.

## Infra

Same bucket as **hstDYDX**: not `LeafOFTAdapter`. Needs a Cosmos/IBC lockbox (PDA-class, not OFT adapter).

**Do not start that lockbox before hJitoSOL’s Solana program has a working spec-and-smoke path.** Two new non-EVM runtimes in parallel is how we burn quota. Jito is BATCH 5 and already has `docs/SOLANA_JITOSOL.md`. ATOM/stDYDX reuse the “non-EVM source + HyperEVM OFT dest” lesson, not the Solana program.

`ASSET=hstatom` must stay `NotThisBatch` until that lockbox exists.

## Sources

- pSTAKE deprecation: https://blog.pstake.finance/2025/11/06/final-reminder-erc-20-stkatom-deprecation
- Evmos shutdown (Prop 331, May 2025)
- Axelar asset list includes bridged `stATOM` / `stuatom` — that is the trap, not the inner
- Existing catalog row: `hstDYDX` (`listings/catalog.json`)
