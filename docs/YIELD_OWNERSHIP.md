# Yield ownership

Industry lesson (Lido wstETH, rETH, JitoSOL): **intrinsic yield belongs
to the token unit**, not to an EOA. Rebasing is optional; share-price is
what DeFi can actually hold in an AMM.

HyperLeaf does **not** rebase Leaf. We pick the accounting per yield type.

| Yield type | Model | Where 99% lives | Protocol 1% | LP / lend |
| --- | --- | --- | --- | --- |
| Rate / ERC-4626 / LST (`hcbETH`, `hsWBERA`, `hgSOON`, Morpho, later `hwstETH`) | **Share-price** (`retainRateYield`) | Stays in inner. Redeem more valuable receipt. | Skim 1% of surplus to converter → HYPE | Captures the 99%. No claim button. |
| Side token (`hxSQUID` QUID, hKAITO eco ERC-20s) | **Rewarder** | WHYPE `notify` by address | 1% at notify | Does **not** capture. See `HYPE_COMPOSABILITY.md`. |
| Foreign ledger (`hORDER`) | Ledger principal + harvest | Harvest token via Rewarder | 1% at notify | Same as side token until a wrapper. |
| Locked NFT | Position NAV | Not this adapter | — | — |

Do **not**:

- Rebase hToken (Uniswap / lending / bridges hate it).
- Fold WHYPE into inner NAV (mixed basket; redeem would not be “the receipt”).
- Sell 99% of a rate surplus to HYPE and then pretend the Leaf is still an LST.
- Give Uniswap a `claim()` (it cannot split to LP tokens).

`hcbETH` is the share-price sample: `setRateKind(ExchangeRate)` +
`setRetainRateYield(true)`. Pull only `surplus × 1%`. Wrap/redeem settle
that 1% before minting or paying out so new deposits are not taxed for a
move they missed. The rest never leaves the lockbox. `hxSQUID` is the
Rewarder sample.

Integer floor: 1% of surplus below 100 inner atoms is **0**. Watermark
still advances. Low-TVL rate vaults can be protocol-unprofitable; dust
stays with holders. Document that in the UI (`GROK_BOT_FRONTEND.md`).

A wstETH-style `whAsset` wrapper (vault that holds Leaf + claims HYPE into
share price) is the DeFi face for Rewarder listings. Not built yet. Do not
ship it until a listing that actually needs LP of a side-token yield is live.

**LP is optional.** Share-price Leaf keeps intrinsic yield in the token, so
an AMM pair would capture it. Rewarder Leaf does not pay HYPE to the pair;
we are not adding gauges to paper over that. Early liquidity, if any, is a
peer claim board (`docs/CLAIM_MARKET.md`), not a subsidised spot pool.


Source of truth for copy: `GROK_BOT_FRONTEND.md`. Solvency rows must name
which column they are.
