# HyperLeaf

**Infrastructure for liquid staking on HyperEVM.**

Bring more assets onto HyperEVM, and keep the extra income of holding them — staking yield, points, fee share, lock multipliers.

HyperLeaf wraps staking receipts and locked positions into tradable ERC-20s on HyperEVM. Native vaults (hNEST) sit next to cross-chain wraps (LayerZero). One listing, one risk, one ticker.

App: [hyperleaf.finance](https://hyperleaf.finance) · X: [@HyperLeafHQ](https://x.com/HyperLeafHQ)

> Mainnet HyperEVM (999) **hNEST is live and capped**. Wrap listings are **code-ready, not deployed**. **Not externally audited.** Do not deposit funds you cannot lose.

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
| **Cross-chain wrap** | Base / BSC / later Solana | `hKAITO`, `hxSQUID`, `VIRTUAL4Y`, … | Contracts in this repo, not mainnet |

Each listing is isolated. A bug or pause in one lockbox does not move another listing’s backing.

---

## Listing kinds (wrap)

Never mix exits on one pair. Never turn a live C1 into C2.

| Kind | When | Source contract | HyperEVM | Exit |
| ---- | ---- | --------------- | -------- | ---- |
| **L** | Transferable receipt | `LeafOFTAdapter` | `LeafOFT` (`h` + asset) | Instant: return the **same receipt** |
| **C1** | Long lock / no liquid receipt | `LeafInboundLockbox` | `LeafClosedOFT` (lock in ticker) | **Market only**. `send` reverts |
| **C2** | Unstake exists, known wait | `LeafRedeemQueue` | `LeafOFT` | Burn → wait `redeemDelay` → `claim` on source |

LayerZero V2 OFT. Users pay the Executor. HyperLeaf does **not** run a 24h relayer or VPS for mint/burn.

Full table: [`listings/catalog.json`](listings/catalog.json) · kinds: [`docs/wrap-kinds.md`](docs/wrap-kinds.md)

---

## Assets

| Ticker | Kind | Source | Inner | Exit | Status |
| ------ | ---- | ------ | ----- | ---- | ------ |
| **hNEST** | Native | HyperEVM | NEST / veNEST+HEV | DEX or Nest-side windows | Live, capped |
| **hKAITO** | L | Base | sKAITO | Instant sKAITO | Code ready |
| **hxSQUID** | L | Base | [xSQUID](https://basescan.org/token/0x13af2Db622d167745518aBfD59a8C4FFEe54937a) | Instant xSQUID | Code ready |
| **VIRTUAL4Y** | C1 | Base | VIRTUAL (ve, not a 1:1 ERC-20) | Market only | Code ready |
| **BONK12M** | C1 | Solana | BONK 12-month lock | Market only | Needs Solana lockbox |
| **hMET** | C2 | Solana | MET (~21d unbond) | Queued claim | Needs Solana lockbox |
| **BLUAI4Y** | C1 | BSC | BLUAI 4y | Market only | Code ready (low priority) |

Later EVM LSTs reuse the same Adapter: shMON, sAVAX, wstETH (if the issuer has not shipped their own OFT). Solana/Sui wait on a non-EVM lockbox.

RAM / HYBR official LSTs are **out of scope**. ENA / sENA is **out of scope** (already on HyperCore).

---

## How a wrap listing works

```
Source chain (e.g. Base)
  user locks sKAITO / xSQUID / VIRTUAL
        |  LayerZero message (user pays)
        v
HyperEVM
  mint hKAITO / hxSQUID / VIRTUAL4Y
        |
        +-- trade on HyperEVM DEX  (always)
        +-- L: burn and unlock the same receipt on source
            C1: no protocol redeem
            C2: burn, wait, claim inner on source
```

Security stack (Base <-> HyperEVM): optional 2-of-3 DVNs (LayerZero Labs + Nethermind + Horizen). HyperLeaf’s own DVN is a later **veto**, not required at launch. Do not enable it until a worker is actually online on both chains.

---

## Fees

Protocol revenue is **1% of staking yield only**. Lock, unlock, and queued claim take **no** protocol fee. Users still pay LayerZero messaging + gas.

| Surface | Charged | Not charged |
| ------- | ------- | ----------- |
| **Wrap L / C2** | 1% of *newly accrued* inner yield (`YIELD_FEE_BPS = 100`). 99% to holders via pro-rata redeem / ticket. | Deposit, redeem, claim |
| **Wrap C1** | Same 1% harvest. Remaining 99% stays as extra backing (no protocol redeem). | — |
| **hNEST (live)** | 1% of residual HYPE swept on `harvest` (`feeBps = 100`) | NEST deposit / withdraw |

`harvest()` / `harvestToken()` can be called by anyone on wrap lockboxes. A second harvest with no new yield is a no-op — it does not skim the 99%.

Side rewards that are a different token (e.g. QUID claimed onto an xSQUID lockbox): 1% to the protocol, 99% stays in the lockbox until a dedicated rewarder exists. Do not promise those 99% to hToken holders yet.

Deploy wrap with `FEE_RECIPIENT` (defaults to `OWNER`). Owner can rotate it.

Live NestVault `MAX_FEE_BPS` is 500. Current fee is 1%. Raising it would be an owner call, not a redeploy. This work does **not** redeploy NestVault.

---

## Native: hNEST

First HyperEVM-native vault. Deposits NEST, attaches Nest HEV, issues **hNEST**.

Honest limits (do not market past these):

- `recordCompound` is **disabled** — HyperLeaf does not mint unbacked share-price yield.
- Nest public HYPE Spring is **Nest-side**, not a HyperLeaf claim-HYPE button.
- hNEST is transferable; epoch HYPE vs NEST split is a Nest accounting problem, not 1:1 instant redeem.
- Withdrawals follow Nest/HEV windows plus an idle buffer — not instant 1:1.

A **deposit EpochGate** (this-week lockers wait one epoch before hNEST is transferable) is designed; it is **not** the live mainnet path until redeployed.

### Live contracts (HyperEVM 999)

| Contract | Address |
| -------- | ------- |
| NestVault | `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` |
| HNest | `0x2101621F51D7E05518D6680C62d04Ad47bC4e05D` |
| HevAdapter | `0xc89273ACB22a4e1df81A396FE0Bf6eD6E2CA6fD2` |
| NEST | `0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035` |

---

## Architecture (repo)

```
src/
  NestVault.sol / HNest.sol / HevAdapter.sol   # native hNEST
  lz/                                          # multi-asset wrap
    LeafYieldFee.sol                           # 1% of new yield only
    LeafOFTAdapter.sol                         # L lockbox
    LeafOFT.sol                                # L / C2 HyperEVM token
    LeafInboundLockbox.sol                     # C1 lockbox
    LeafClosedOFT.sol                          # C1 ticker (e.g. VIRTUAL4Y)
    LeafRedeemQueue.sol                        # C2 delayed claim
    LeafSecurity.sol / LayerZeroAddresses.sol
listings/catalog.json                          # canonical asset list
docs/wrap-kinds.md
```

---

## Risk

HyperLeaf makes lock and staking risk **tradable**. It does not remove it.

- Smart-contract risk — **not externally audited**
- C1 closed tickers can trade at a persistent discount to NAV
- Points / airdrops on source stakes usually accrue to the **lockbox address**, not the hToken holder
- LayerZero / DVN / Executor liveness
- Underlying protocol upgrades (Nest HEV, Squid StakedToken, Meteora, ...)
- Deposit caps and pause are expected in the first months of each listing

---

## Develop

```bash
git clone https://github.com/HyperLeafHQ/HyperLeaf
forge test
```

Wrap tests: `test/lz/`. Native tests: `test/NestVault.t.sol`. Deploy scripts: `script/lz/` (`DeployAdapter`, `DeployOFT`, `DeployClosed`, `DeployQueued`, `WirePeers`, `SetSecurityStack`).

Set `OWNER` / `GUARDIAN` to **your** wallets before any mainnet broadcast. Do not leave a bot as owner. Set `FEE_RECIPIENT` for wrap lockboxes (defaults to `OWNER`).

---

## License

MIT
