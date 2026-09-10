# kV-PYUSD — Kamino vault on Solana, after JitoSOL

Verified 2026-09-10. Raw PYUSD is still a dollar. The yield is **Kamino**.

## Do not wrap

| Token | Why |
| --- | --- |
| ETH PYUSD `0x6c3e…A0e8` | Paxos 1:1. 0 native yield. ~1.70B. |
| SOL PYUSD `2b1k…GXo` | Same dollar (Token-2022). |
| Spark `spPYUSD` | ~54k. Skip. |

## Wrap this (later)

**Sentora PYUSD** Kamino Lending Vault.

| | |
| --- | --- |
| Vault | `A2wsxhA7pF4B2UKVfXocb6TAAP9ipfPJam6oMKgDE5BK` |
| Receipt | **kV-PYUSD** (vault shares). Mint cited `DCqyVY1SFCwq8unnexv9pjujVAC7jsmjfoUWBrNLvbY` — re-pin on deploy |
| Docs | [Kamino lending vaults](https://kamino.com/docs/products/lending-vaults.md) |
| Live | ~$112M deposited, 7d ~6% (Sentora, 2026-09). 5% performance / 0% mgmt |

Share count stays flat; **PYUSD per share** rises as Kamino supply interest accrues. Same skim class as JitoSOL.

## What we capture vs what we don’t

| | In share price? | HyperLeaf |
| --- | --- | --- |
| Kamino borrower interest | yes | 1% of surplus |
| PayPal/Paxos PYUSD **subsidy** | only if the vault compounds it | otherwise claimable — lockbox does not harvest unless we add it |
| KMNO farm | usually claimable | **no** unless compounded. Season 5 ended 2026-03-07 |

Subsidy is marketing, not the LST. If incentives taper, APY falls to organic borrow demand (~low single digits on some reserves).

## Infra

Solana lockbox, **after hJitoSOL** (BATCH 5). Not `LeafOFTAdapter`. Kind **C2** (curator vault + Kamino + whatever they allocate, including USDe-collateral markets). Never deposit raw PYUSD into K-Lend from the lockbox (no transferable receipt).

`NotThisBatch`.
