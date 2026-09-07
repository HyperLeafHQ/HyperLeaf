# HyperLeaf

**Infrastructure for liquid staking on HyperEVM.**

Hyperliquid already has deep books and liquid HYPE staking. What it does not have is the rest of the yield-bearing world: locked governance, duration stakes, LSTs that live on Base or Ethereum. Those positions earn, but they cannot trade, lend, or margin here.

HyperLeaf is the **ingress**. You deposit the productive form of an asset. You receive a **Leaf** ticker on HyperEVM. The extra income that position was already earning is paid out as **HYPE**. Other protocols can treat that ticker as collateral, LP, or margin.

> HyperLeaf does not create risk. It makes hidden lock and staking risk tradable.

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

Protocol take is **1% of staking yield only**. You still pay gas and LayerZero. There is no fee to lock or unlock.

**Four words that are not synonyms**

| | Means | Does not mean |
| --- | --- | --- |
| **Backed** | Realizable underlying exists for the supply | You can exit at NAV today |
| **Redeemable** | This listing has a path home (instant or queued) | The DEX is deep |
| **Liquid** | Someone will bid on HyperEVM | Protocol 1:1 |
| **Fungible** | One ticker, one claim | Every listing exits the same way |

If the source cannot unstake freely, the ticker says so (`BLUAI4Y`, `BONK12M`). A discount to NAV on those names is a **liquidity price**, not a depeg — unless the backing is gone.

---

## For HyperEVM protocols

Success is not HyperLeaf TVL. Success is another protocol shipping **“we support Leaf assets.”**

A Leaf ticker is a normal ERC-20 on HyperEVM. Integrations should:

1. Read the listing **kind** (L / C1 / C2) before treating it as instant collateral.
2. Price C1 against the book, not against a 1:1 oracle to the inner token.
3. Isolate listings. A pause on hxSQUID must not touch hNEST or hcbETH.

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

HyperLeaf does not run a 24h mint relayer. Listings do not share backing. The bridge starts **closed**. Caps, a listing tag on every message, and a cash check on redeem are in the contracts — see [`docs/PEG.md`](docs/PEG.md).

**Yield, in HYPE.** Surplus on the source (claimed QUID, extra farm tokens, airdrop ERC-20s) is converted to WHYPE. 99% is claimable by Leaf holders. 1% is protocol revenue. The inner receipt that backs the ticker is never pulled as “yield.”

**hNEST** is native: NEST stays on HyperEVM, attaches Nest HEV, issues hNEST. It is capped. Compound of extra NEST is not live. Withdrawals follow Nest/HEV windows, not instant 1:1.

| Contract (HyperEVM 999) | Address |
| ----------------------- | ------- |
| NestVault | `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` |
| HNest | `0x2101621F51D7E05518D6680C62d04Ad47bC4e05D` |
| HevAdapter | `0xc89273ACB22a4e1df81A396FE0Bf6eD6E2CA6fD2` |
| NEST | `0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035` |

---

## What ships next

One listing at a time. Empty books and mixed exits do not help the ecosystem.

| | Ticker | Kind | Source | For users |
| --- | --- | --- | --- | --- |
| Live | **hNEST** | Native | HyperEVM | NEST / veNEST as a HyperEVM ERC-20 |
| Next | **hxSQUID** | L | Base | Trade xSQUID here; QUID surplus → HYPE |
| Then | **hcbETH** | L | Base | ETH PoS exposure on HyperEVM |
| Later | **hgSOON**, **PTSMAX**, hB3, hORDER, hAVNT, hsETHFI, veAERO, … | | | Same pattern: keep the yield, name the lock |
| Not now | hSKY, hLIT, stkAAVE, extra-chain airdrop names | | | LIT waits on Lighter LZ. SKY strips borrow |

Out of scope: another HYPE LST, wrapping official RAM/HYBR receipts, ENA (already on HyperCore).

---

## Risk

HyperLeaf **markets** lock and staking risk. It does not delete it.

- Contracts are **not externally audited**
- C1 names can sit below NAV for a long time
- Source points and airdrops accrue to the vault until harvested
- LayerZero delivery and thin HYPE books on source chains
- Underlying protocols (Nest, Squid, Coinbase cbETH, …) can change
- Early listings are capped and pausable

---

## Docs

| | |
| --- | --- |
| Kinds and exits | [`docs/wrap-kinds.md`](docs/wrap-kinds.md) |
| Yield → HYPE | [`docs/HYPE_YIELD.md`](docs/HYPE_YIELD.md) |
| Listing catalog | [`listings/catalog.json`](listings/catalog.json) |
| Internal order | [`docs/ROADMAP.md`](docs/ROADMAP.md) |
| Deploy / keys | [`docs/OPERATOR.md`](docs/OPERATOR.md) |
| Testnet | [`docs/GROK_BOT_TESTNET.md`](docs/GROK_BOT_TESTNET.md) |

```bash
git clone -b feat/lz-oft-wrap https://github.com/HyperLeafHQ/HyperLeaf
forge test
```

## License

MIT
