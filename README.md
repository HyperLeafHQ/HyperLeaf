# HyperLeaf

**Infrastructure for liquid staking on HyperEVM.**

Hyperliquid already has deep books and liquid HYPE staking. What it does not have is the rest of the yield-bearing world: locked governance, duration stakes, LSTs that live on Base or Ethereum. Those positions earn, but they cannot trade, lend, or margin here.

HyperLeaf is the **ingress**. You deposit the productive form of an asset. You receive a **Leaf** ticker on HyperEVM. The extra income that position was already earning is paid out as **HYPE**. Other protocols can treat that ticker as collateral, LP, or margin.

> HyperLeaf does not create risk. It makes hidden lock and staking risk tradable.

> **HyperLeaf does not provide liquidity. It provides an exit venue for otherwise illiquid claims.**

App: [hyperleaf.finance](https://hyperleaf.finance) · X: [@HyperLeafHQ](https://x.com/HyperLeafHQ)

Live on HyperEVM (999): **hNEST**, capped. Wrap listings are in this repo and **not deployed**. **Not externally audited.** Do not deposit funds you cannot lose.

---

## For holders

You already hold something that earns — xSQUID, cbETH, a four-year farm, veNEST. On its home chain it is stuck or thin. On HyperEVM you want a market, a lending pool, and yield in HYPE.

| You get | You do not get |
| ------- | -------------- |
| A HyperEVM ERC-20 for that **specific** claim | A generic wrapped copy of the spot token |
| The same economic state: principal, yield, lock | A promise that every ticker exits 1:1 anytime |
| New staking surplus paid in **WHYPE** | Deposit / withdraw protocol fees |
| A book you can sell into | The protocol taking lock or borrow risk for you |
| An exit board for claims that cannot unwrap today | An AMM, a treasury bid, or a promised 1:1 dump |

Protocol take is **1% of staking yield only**. You still pay gas and LayerZero. There is no fee to lock or unlock. The exit board's 1% is a **buyer incentive from the seller's ask** — it is not HyperLeaf revenue.

**Four words that are not synonyms**

| | Means | Does not mean |
| --- | --- | --- |
| **Backed** | Realizable underlying exists for the supply | You can exit at NAV today |
| **Redeemable** | This listing has a path home (instant or queued) | The DEX is deep |
| **Liquid** | Someone will bid on HyperEVM | Protocol 1:1 |
| **Fungible** | One ticker, one claim | Every listing exits the same way |

If the source cannot unstake freely, the ticker says so (`BLUAI4Y`, `BONK12M`). A discount to NAV on those names is a **liquidity price**, not a depeg — unless the backing is gone.

Early books will be thin. HyperLeaf will **not** seed an AMM or buy the other side. C1 (no protocol redeem) and long-window names like hNEST use a **peer-to-peer exit board**: you list a Leaf at a fixed ask, someone who was going to deposit inner buys it, 1% of the ask is a **buyer incentive** (not a protocol fee). No bid, no trade. Occupancy HYPE while listed goes to the protocol **only on Rewarder tickers** (not hNEST). Price does not follow NAV after you list. Cross-chain fill is done when source emits `Paid`, not when dest releases the Leaf.

C1 is the only protocol exit. hNEST on the board is an *early* exit before the official window — do not mix the two in copy.

Details: [`docs/CLAIM_MARKET.md`](docs/CLAIM_MARKET.md).

---

## For HyperEVM protocols

Success is not HyperLeaf TVL. Success is another protocol shipping **“we support Leaf assets.”**

A Leaf ticker is a normal ERC-20 on HyperEVM. Integrations should:

1. Read the listing **kind** (L / C1 / C2) before treating it as instant collateral.
2. Price C1 against the book, not against a 1:1 oracle to the inner token.
3. Isolate listings. A pause on hxSQUID must not touch hNEST or hcbETH.
4. Treat [`docs/SOLVENCY.md`](docs/SOLVENCY.md) as the reason the ticker exists — not the catalog.

When a ticker has a real book, it can be **linked as a Core spot** so lending and HIP-3 read HyperCore prices. That is the path from “wrapper” to default collateral. HyperLeaf does not run a trading vault and does not take directional risk in HyperCore.

---

## How a Leaf is made

```
Your position on Base / BSC / Ethereum / HyperEVM
        │  lock the receipt or the locked stake
        │  LayerZero message (you pay the Executor)
        ▼
HyperEVM Leaf ticker
        ├── trade
        ├── L:  burn → same receipt back, instantly
        ├── C1: sell the ticker (no protocol redeem)
        └── C2: burn → wait → claim on source
```

HyperLeaf does not run a 24h mint relayer. Listings do not share backing. The bridge starts **closed**. Caps, a listing tag on every message, a cash check on redeem, and a **health / inner-supply ceiling** (do not mint because a token contract printed) are in the contracts — see [`docs/PEG.md`](docs/PEG.md), [`docs/TRUST.md`](docs/TRUST.md), [`docs/SOLVENCY.md`](docs/SOLVENCY.md).

**Yield, in HYPE.** Side tokens (QUID, extra farm, airdrops) convert to WHYPE. Rate-bearing receipts (cbETH) sell only the official `exchangeRate` surplus — that slice is yield, not principal. 99% is claimable by Leaf holders. 1% is protocol revenue, taken at `notify` in WHYPE. Side-token listings stay 1:1 on redeem. After a rate harvest, redeem is remaining inner, not 1 token = 1 token.

**hNEST** is native: NEST stays on HyperEVM, attaches Nest HEV, issues hNEST. It is capped. Compound of extra NEST is not live. Withdrawals follow Nest/HEV windows, not instant 1:1.

| Contract (HyperEVM 999) | Address |
| ----------------------- | ------- |
| NestVault | `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` |
| HNest | `0x2101621F51D7E05518D6680C62d04Ad47bC4e05D` |
| HevAdapter | `0xc89273ACB22a4e1df81A396FE0Bf6eD6E2CA6fD2` |
| NEST | `0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035` |

---

## What ships next

One listing at a time. Empty books and mixed exits do not help the ecosystem. Wrap a **transferable receipt**, never the spot token, never the protocol’s unstake.

| | Ticker | Kind | Source | For users |
| --- | --- | --- | --- | --- |
| Live | **hNEST** | Native | HyperEVM | NEST / veNEST as a HyperEVM ERC-20 |
| Canary | **hCANARY** | L | Base | Toy token on the real LZ stack. Not a product |
| Batch 1 | **hxSQUID**, **hAVNT** | L | Base | Trade xSQUID / stkAVNT here; QUID or AVNT surplus → HYPE |
| Batch 2 | **hcbETH**, **hgSOON**, **hsWBERA** | L | Base / BSC / Bera | Rate surplus 1% protocol / 99% stays in the receipt |
| Batch 3 | **hsAVAX**, **hsETHFI**, **hstkwaUSDC** | L | Avax / Ethereum | BENQI; ether.fi receipt; Umbrella USDC |
| Batch 4 | **BLUAI4Y**, **hORDER** | C1 | BSC / Arbitrum | Market exit. No protocol redeem. No CREATE2 twin |
| Morpho vaults | **hsteakUSDC**, **hsteakUSDG** | L | Base / Robinhood | Wrap the ERC-4626 **share**. Never deposit/redeem USDC/USDG. Never Morpho Blue positions |
| Later C1 | hB3, PTSMAX | C1 | Base / BSC | Address-keyed farm or NFT. Market exit |
| Needs new lockbox | **hJitoSOL**, veAERO, veUP, JupSOL, stDYDX | L / ve-NFT | Solana / Base / Robinhood / Cosmos | JitoSOL dest+math is BATCH=5; Solana program next. NFT/IBC later |
| Not now | hKAITO, hVIRTUALMAX, hSKY, hGMX, hUNCX, hSNX, hLIT, **stkAAVE**, SLVR, TWO, StonkBrokers | | | Omnichain / frozen / tax / NFT TBA. Legacy stkAAVE stays HOLD — Umbrella is hstkwaUSDC. Full order: [`docs/ROADMAP.md`](docs/ROADMAP.md) |

Out of scope: another HYPE LST, wrapping official RAM/HYBR receipts, ENA (already on HyperCore).

---

## Risk

HyperLeaf **markets** lock and staking risk. It does not delete it.

- Contracts are **not externally audited**. Architecture is specified by a human. Implementation is written by AI developers. Read it as unaudited generated code on a human design — not as a substitute for review.
- C1 names can sit below NAV for a long time. That is a liquidity price, not a HyperLeaf peg, unless backing is gone. **The protocol does not guarantee a buyer or a book.**
- HyperLeaf is infrastructure, availability, and yield split (99/1 of staking surplus). It does not make markets. The exit board is matching only; the treasury never bids.
- Source points and airdrops accrue to the vault until harvested
- LayerZero delivery and thin HYPE books on source chains
- Underlying protocols (Nest, Squid, Coinbase cbETH, …) can change
- Early listings are capped and pausable

---

## Docs

| | |
| --- | --- |
| Kinds and exits | [`docs/wrap-kinds.md`](docs/wrap-kinds.md) |
| Exit board (not an AMM) | [`docs/CLAIM_MARKET.md`](docs/CLAIM_MARKET.md) |
| Frontend bot (no L/C1/C2 on UI) | [`docs/GROK_BOT_FRONTEND.md`](docs/GROK_BOT_FRONTEND.md) |
| Yield → HYPE | [`docs/HYPE_YIELD.md`](docs/HYPE_YIELD.md) |
| Listing catalog | [`listings/catalog.json`](listings/catalog.json) |
| Internal order | [`docs/ROADMAP.md`](docs/ROADMAP.md) |
| Deploy / keys | [`docs/OPERATOR.md`](docs/OPERATOR.md) |
| Deploy / canary | [`docs/GROK_BOT_MAINNET.md`](docs/GROK_BOT_MAINNET.md) |

```bash
git clone -b feat/lz-oft-wrap https://github.com/HyperLeafHQ/HyperLeaf
forge test
```

## License

MIT
