# HyperLeaf

**Unit for LSTs.** Every yield-bearing receipt deserves a HyperEVM market.

HyperLeaf brings staking and locked assets onto Hyperliquid as tradable ERC-20s. Native HyperEVM vaults (hNEST) sit next to cross-chain wraps (LayerZero). One listing, one risk, one ticker — not a single Nest-only product.

App: [hyperleaf.finance](https://hyperleaf.finance) · X: [@HyperLeafHQ](https://x.com/HyperLeafHQ)

> Mainnet HyperEVM (999) **hNEST is live and capped**. Wrap listings are **code-ready, not deployed**. **Not externally audited.** Do not deposit funds you cannot lose.

---

## Why it exists

Hyperliquid already has **Unit** for canonical assets (uETH, uSOL, uBONK…). It does not wrap the *staked / locked* form of those assets, and it does not list every long-tail token with real yield.

HyperLeaf fills that gap:

1. **Pair with Unit** — `VIRTUAL4Y` next to `uVIRTUAL`, `BONK12M` next to `uBONK`, LST receipts next to the Unit spot.
2. **Introduce assets Unit does not list** — sKAITO, xSQUID, MET, and others with PoS / points / fee share.
3. **Price the lock** — if the source cannot unstake freely, the HyperEVM ticker says so (`BLUAI4Y`, `VIRTUAL4Y`). Exit is the book, not a fake 1:1 redeem.

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
| **L** | Transferable receipt, or unstake is the user’s problem | `LeafOFTAdapter` | `LeafOFT` (`h` + asset) | Instant: return the **same receipt** |
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

Later EVM LSTs that reuse the same Adapter: shMON, sAVAX, wstETH (only if Lido has not already shipped an OFT). Solana/Sui (JupSOL, SUI LSTs) wait on a non-EVM lockbox.

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

Set `OWNER` / `GUARDIAN` to **your** wallets before any mainnet broadcast. Do not leave a bot as owner.

---

## License

MIT
