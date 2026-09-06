# HyperLeaf

**Infrastructure for liquid staking on HyperEVM.**

Bring more assets onto HyperEVM, and keep the extra income of holding them — staking yield, points, fee share, lock multipliers.

HyperLeaf wraps staking receipts and locked positions into tradable ERC-20s on HyperEVM. Native vaults (hNEST) sit next to cross-chain wraps (LayerZero). One listing, one risk, one ticker.

App: [hyperleaf.finance](https://hyperleaf.finance) · X: [@HyperLeafHQ](https://x.com/HyperLeafHQ)

> Mainnet HyperEVM (999) **hNEST is live and capped**. Wrap listings are **code-ready, not deployed**. **Not externally audited.** Do not deposit funds you cannot lose.

Wrap contracts and the asset catalog live on branch [`feat/lz-oft-wrap`](https://github.com/HyperLeafHQ/HyperLeaf/tree/feat/lz-oft-wrap) until merged.

---

## Why it exists

HyperEVM still lacks a default layer for *staked and locked* assets. Spot can already show up through other bridges. The missing piece is the yield-bearing form: liquid receipts, vote-escrow, duration locks — still earning on the source protocol, still tradable on HyperEVM.

1. **Introduce the asset** — sKAITO, xSQUID, MET, and other tokens that are not native to HyperEVM.
2. **Keep the extra income** — wrap the receipt or the lock, not only the dead spot. PoS, points, fee share stay with the underlying position.
3. **Price the lock** — if the source cannot unstake freely, the ticker says so (`VIRTUAL4Y`, `BONK12M`, `BLUAI4Y`). Exit is the book, not a fake 1:1 redeem.

---

## Two product lines

| Line | Where the asset lives | HyperEVM token | Status |
| ---- | --------------------- | -------------- | ------ |
| **Native vault** | Already on HyperEVM | `hNEST` | Live (capped) |
| **Cross-chain wrap** | Base / BSC / later Solana | `hKAITO`, `hxSQUID`, `VIRTUAL4Y`, … | Contracts ready, not mainnet |

Each listing is isolated. A bug or pause in one lockbox does not move another listing’s backing.

---

## Listing kinds (wrap)

Never mix exits on one pair. Never turn a live C1 into C2.

| Kind | When | Source contract | HyperEVM | Exit |
| ---- | ---- | --------------- | -------- | ---- |
| **L** | Transferable receipt | `LeafOFTAdapter` | `LeafOFT` (`h` + asset) | Instant: return the **same receipt** |
| **C1** | Long lock / no liquid receipt | `LeafInboundLockbox` | `LeafClosedOFT` (lock in ticker) | **Market only** |
| **C2** | Unstake exists, known wait | `LeafRedeemQueue` | `LeafOFT` | Burn, wait, `claim` on source |

LayerZero V2 OFT. Users pay the Executor. HyperLeaf does **not** run a 24h relayer.

---

## Assets

| Ticker | Kind | Source | Inner | Exit | Status |
| ------ | ---- | ------ | ----- | ---- | ------ |
| **hNEST** | Native | HyperEVM | NEST / veNEST+HEV | DEX or Nest-side windows | Live, capped |
| **hKAITO** | L | Base | sKAITO | Instant sKAITO | Code ready |
| **hxSQUID** | L | Base | [xSQUID](https://basescan.org/token/0x13af2Db622d167745518aBfD59a8C4FFEe54937a) | Instant xSQUID | Code ready |
| **VIRTUAL4Y** | C1 | Base | VIRTUAL (ve) | Market only | Code ready |
| **BONK12M** | C1 | Solana | BONK 12-month lock | Market only | Needs Solana lockbox |
| **hMET** | C2 | Solana | MET (~21d unbond) | Queued claim | Needs Solana lockbox |
| **BLUAI4Y** | C1 | BSC | BLUAI 4y | Market only | Code ready (low priority) |

Later EVM LSTs reuse the same Adapter: shMON, sAVAX, wstETH (if the issuer has not shipped their own OFT). Solana/Sui wait on a non-EVM lockbox.

RAM / HYBR official LSTs are **out of scope**. ENA / sENA is **out of scope** (already on HyperCore).

---

## Fees

Protocol revenue is **1% of staking yield only**. Deposits, withdrawals, and wrap lock/unlock/claim take **no** protocol fee. Users still pay LayerZero messaging + gas.

| Surface | Charged | Not charged |
| ------- | ------- | ----------- |
| **Wrap L / C2** | 1% of newly accrued inner yield. 99% to holders on redeem. | Lock / unlock / claim |
| **Wrap C1** | Same 1%. Remaining 99% stays as extra backing. | No protocol redeem |
| **hNEST (live)** | 1% of residual HYPE on `harvest` (`feeBps = 100`) | NEST deposit / withdraw |

Live NestVault is not redeployed for this. Wrap fee code lives on `feat/lz-oft-wrap`.

---

## Native: hNEST (live)

| Contract | Address (HyperEVM 999) |
| -------- | ------- |
| NestVault | `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` |
| HNest | `0x2101621F51D7E05518D6680C62d04Ad47bC4e05D` |
| HevAdapter | `0xc89273ACB22a4e1df81A396FE0Bf6eD6E2CA6fD2` |
| NEST | `0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035` |

Honest limits: `recordCompound` disabled; Nest HYPE Spring is Nest-side; withdrawals are not instant 1:1.

---

## Risk

- **Not externally audited**
- C1 tickers can trade below NAV
- Source points/airdrops usually accrue to the lockbox, not the hToken holder
- LayerZero / DVN / Executor liveness

---

## License

MIT
