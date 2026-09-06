# HyperLeaf

**Infrastructure for liquid staking on HyperEVM.**

Not another HYPE LST. kHYPE and stHYPE already proved people will hold yield-bearing HYPE. HyperLeaf does not compete on a slightly higher APY.

It is the **ingress layer**: take assets that would not otherwise live on HyperEVM, **keep their economic state** (principal, yield, lock, exit), and issue a **Leaf asset** other protocols can use as collateral, LP, or margin.

> Bring assets. Keep their yield. Make them productive.

Spot bridges already move dead tokens. HyperLeaf moves the *yield-bearing form* — liquid receipts, vote-escrow, duration locks — and pays **new staking yield in HyperEVM HYPE** (WHYPE). Protocol take: **1% of that yield only**. No deposit or withdraw fee.

App: [hyperleaf.finance](https://hyperleaf.finance) · X: [@HyperLeafHQ](https://x.com/HyperLeafHQ)

> Mainnet HyperEVM (999): **hNEST is live and capped**. Wrap listings and HYPE conversion are **in this repo, not deployed**. **Not externally audited.** Do not deposit funds you cannot lose.

A Leaf asset is **not a wrapped copy**. It is the HyperEVM financial form of that claim. Success is not HyperLeaf TVL. Success is a third protocol saying **“we support Leaf assets.”**

---

## Four words we will not mix

| Word | Means | Does **not** mean |
| ---- | ----- | ----------------- |
| **Backed** | Realizable underlying exists for outstanding Leaf supply | You can exit at NAV today |
| **Redeemable** | This listing has a protocol path home (L instant, C2 queued) | The book is deep |
| **Liquid** | Someone will bid on a HyperEVM DEX | Protocol 1:1 |
| **Fungible** | One ticker, one claim type | Every listing exits the same way |

C1 (`hVIRTUALMAX`, `BLUAI4Y`, `BONK12M`) is **backed, not protocol-redeemable**. Market below NAV is a liquidity price, not a depeg — unless backing itself is gone. UI must never print “1 hX = 1 X, anytime.”

L / C1 / C2 are the product, not patches. Different assets have different exit topology; HyperEVM still sees one ERC-20.

---

## Representation invariant

At every moment, for every listing:

```
outstanding Leaf claims  ≤  economically realizable underlying
                           (principal + booked yield − pending redemptions − fees)
```

Not `balanceOf(lockbox)`. Realizable. Principal is never harvested as yield. Yield is never booked twice. A burn drops liabilities **before** assets leave. Cross-chain minted supply equals canonical locked claims.

If a PR cannot show this still holds, it does not merge.

---

## Code status

| What | Where | Deployed? |
| ---- | ----- | --------- |
| Live hNEST (NestVault / HNest / HevAdapter) | [`main`](https://github.com/HyperLeafHQ/HyperLeaf) | HyperEVM 999, capped |
| Wrap L / C1 / C2 + LayerZero OFT + **yield → HYPE** | this branch [`feat/lz-oft-wrap`](https://github.com/HyperLeafHQ/HyperLeaf/tree/feat/lz-oft-wrap) · [PR #4](https://github.com/HyperLeafHQ/HyperLeaf/pull/4) | No |
| Next NestVault (verified 1% compound fee + mint-delay EpochGate) | [`feat/hnest-yield-fee-gate`](https://github.com/HyperLeafHQ/HyperLeaf/tree/feat/hnest-yield-fee-gate) · [PR #5](https://github.com/HyperLeafHQ/HyperLeaf/pull/5) | No — live vault is not this code |

Default GitHub `main` is the live NestVault only. **HYPE conversion (`LeafHypeRewarder`, `pullYield`, `convertYieldToHype`) is this wrap branch.** It is not on `main` until PR #4 merges.

---

## Why it exists

HyperEVM is a trading network, not a general-purpose L1 full of every asset. HyperLeaf’s job is to **bring the missing productive collateral in**, without stripping the yield that made the asset worth holding.

1. **Ingress** — sKAITO, xSQUID, wstETH, MET … tokens that are not native here.
2. **Keep the extra income** — wrap the receipt or the lock, not only dead spot.
3. **Pay that income in HYPE** — “use assets you already have to earn HYPE.”
4. **Tell the truth about the lock** — if the source cannot unstake freely, the ticker says so (`hVIRTUALMAX`, `BONK12M`, `BLUAI4Y`). Exit is the book, not a fake 1:1 redeem.

What we are **not**: a Kinetiq competitor, a points farm, a generic LayerZero wrapper, or a protocol whose north star is APY.

---

## Two product lines

| Line | Where the asset lives | HyperEVM token | Yield |
| ---- | --------------------- | -------------- | ----- |
| **Native vault** | Already on HyperEVM | `hNEST` | Nest-side HYPE + (later) verified NEST compound |
| **Cross-chain wrap** | Base / BSC / later Solana | `hKAITO`, `hxSQUID`, `hVIRTUALMAX`, … | Surplus inner/side tokens → WHYPE |

Each listing is isolated. A bug or pause in one lockbox does not move another listing’s backing.

LayerZero is a pipe. The product is the Leaf asset on HyperEVM.

---

## How we measure this

Headline TVL is easy to rent. We care, in order:

1. **Non-incentivized TVL** — would they stay if points stopped?
2. **Integration count** — lending, DEX, vaults, (later) perps that treat a Leaf asset as collateral.
3. **Utilization** — share of Leaf supply actually sitting in those protocols, not idle in wallets.
4. **Honest books** — one listing at a time; redeem matches lock; yield is not principal.
5. **Fee revenue** — 1% of real yield, from volume, not from locking users in.

A $100M book used as collateral in twenty places beats a $500M farm with two pools.

---

## Mechanisms

### 1. Wrap: lock on source, mint on HyperEVM

LayerZero V2 OFT. Users pay the official Executor. HyperLeaf does **not** run a 24h mint/burn relayer.

```
Source chain (Base / BSC / …)
  user locks the inner receipt or the locked position
        |  LayerZero message (user pays)
        v
HyperEVM
  mint the listing ticker
        |
        +-- trade on a HyperEVM DEX  (always)
        +-- L:  burn → unlock the **same receipt** on source (instant)
        +-- C1: no protocol redeem; sell the ticker
        +-- C2: burn → wait → `claim` inner on source
```

Never mix exits on one pair. Never turn a live C1 into C2.

| Kind | When | Source | HyperEVM | Exit |
| ---- | ---- | ------ | -------- | ---- |
| **L** | Transferable receipt | `LeafOFTAdapter` | `LeafOFT` | Instant: same receipt |
| **C1** | Long lock / no liquid receipt | `LeafInboundLockbox` | `LeafClosedOFT` | Market only. `send` reverts |
| **C2** | Unstake exists, known wait | `LeafRedeemQueue` | `LeafOFT` | Burn, wait `redeemDelay`, `claim` |

Security (Base ↔ HyperEVM): optional 2-of-3 DVNs (LayerZero Labs + Nethermind + Horizen). A HyperLeaf DVN veto is later, and stays off until a worker is actually online on both chains.

### 2. Yield → HyperEVM HYPE (wrap)

Two steps. Do not merge them into one on-chain swap.

1. **Anyone**, source chain: `LeafCallRewardSource.harvest(lockbox)` (or the farm claim) — settled QUID / BLUAI land **in** the lockbox. Caller pays gas. No DEX.
2. **Keeper**, weekly or when the batch clears Relay min: `pullYield` → swap/bridge → `LeafHypeRewarder.notify` (**1% / 99%**). Users `claim` WHYPE.

L adapters **cannot** `pullYield` sKAITO / xSQUID. C1 **can** pull extra BLUAI above `totalLocked`.

| Listing | Unlock | Pull to HYPE | Never pull |
| ------- | ------ | ------------ | ---------- |
| hKAITO | L, sKAITO | Eco airdrop ERC-20s | sKAITO (PoS already in the 4626 rate) |
| hxSQUID | L, xSQUID | QUID | xSQUID |
| BLUAI4Y | C1, market only | Extra BLUAI (`pullInnerEnabled`) | Principal (`totalLocked`) |

`pullInnerEnabled` is not a switch: L forbids inner pulls, C1 allows surplus BLUAI. Details: [`docs/HYPE_YIELD.md`](docs/HYPE_YIELD.md).

### 3. Native: hNEST

Deposits NEST, attaches Nest HEV, issues **hNEST**.

Honest limits of the **live** vault:

- `recordCompound` is **disabled** — no unbacked share-price mint.
- Nest public HYPE Spring is **Nest-side**, not a HyperLeaf claim button.
- Withdrawals follow Nest/HEV windows plus an idle buffer — not instant 1:1.
- Live fee: **1% of residual HYPE** on `harvest` (`feeBps = 100`). NEST deposit / withdraw: **0%**.

Designed, not live (PR #5):

- Verified compound: book only `pendingLockedNestShare` deltas; 1% of that growth as protocol shares, 99% NAV to holders.
- **EpochGate is a mint delay**, not a transfer lock. Circulating hNEST stays a normal ERC-20. New deposits wait one Nest epoch before hNEST is minted.

### Live contracts (HyperEVM 999)

| Contract | Address |
| -------- | ------- |
| NestVault | `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` |
| HNest | `0x2101621F51D7E05518D6680C62d04Ad47bC4e05D` |
| HevAdapter | `0xc89273ACB22a4e1df81A396FE0Bf6eD6E2CA6fD2` |
| NEST | `0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035` |

---

## Fees

Protocol revenue is **1% of staking yield only**. Lock, unlock, queued claim, and NEST deposit/withdraw take **no** protocol fee. Users still pay LayerZero + gas.

| Surface | Charged | Not charged |
| ------- | ------- | ----------- |
| **Wrap (HYPE convert on)** | 1% of WHYPE at `notify`. 99% claimable. Redeem of principal is 1:1. | Lock / unlock / claim |
| **Wrap (legacy inner harvest)** | 1% of newly accrued inner; 99% stays in the box / backing | Same |
| **hNEST live** | 1% of residual HYPE on `harvest` | NEST in / out |

---

## Assets and launch order

Listings go **one path at a time**. Same chain + same Kind can batch after that path is proven. Do not launch nine tickers on day one: nine empty books, nine harvest routes, nine blast radii.

Success for a listing is not “it compiled.” It is: small deposit and redeem match, principal cannot be pulled as yield, and one real surplus has become claimable HYPE.

| Order | Ticker | Kind | Source | Inner | Why this slot |
| ----- | ------ | ---- | ------ | ----- | ------------- |
| 0 (live) | **hNEST** | Native | HyperEVM | NEST / veNEST+HEV | Already on mainnet, capped |
| 1 | **hKAITO** | L | Base | sKAITO | First wrap: Base, instant redeem, simplest story. Cap tiny. Harvest airdrops; do not auto-sell sKAITO rebase. |
| 2 | **hxSQUID** | L | Base | [xSQUID](https://basescan.org/token/0x13af2Db622d167745518aBfD59a8C4FFEe54937a) | Same chain, same L contracts. QUID is real-time yield — first clean HYPE-convert drill. |
| 3 | **hwstETH** | L | Ethereum / LST home | wstETH | After L is trusted. Pairs against Unit uETH — this is the liquidity thesis. |
| 4 | **hVIRTUALMAX** | C1 | Base | VIRTUAL → Virtuals Auto Max-lock (`stake(…, 104, true)`) | Never official redeem. ve stays 1:1. Agent airdrops → HYPE. |
| 5 | **hshMON** | L | Monad | shMON | Same Adapter as other EVM LSTs. |
| later | **BLUAI4Y** | C1 | BSC | BLUAI 4y | High user risk. First use of the BSC → Relay → WHYPE route. |
| last | **BONK12M** | C1 | Solana | BONK 12-month lock | Needs a Solana lockbox. Not in this EVM repo yet. |
| last | **hMET** | C2 | Solana | MET (~21d unbond) | Same. |

RAM / HYBR official LSTs are **out of scope**. ENA / sENA is **out of scope** (already on HyperCore). Hyperliquid-native LSTs (HYPE LST) are **out of scope**.

Catalog: [`listings/catalog.json`](listings/catalog.json) · kinds: [`docs/wrap-kinds.md`](docs/wrap-kinds.md).

---

## Roadmap

**Phase A — testnet, one L end-to-end**
Deploy mock hKAITO on Base testnet + HyperEVM testnet. Deposit, mint, redeem, `pullYield`, `notify`, claim HYPE. Then one C1 mock and one C2 mock so the three exits are not confused.

**Phase B — mainnet hKAITO only**
Tiny cap. Watch LZ peers, DVN, Executor quotes. Harvest side airdrops to WHYPE if size is real; skip sKAITO share-growth sells.

**Phase C — hxSQUID, then hwstETH**
Copy the proven Base L path. Seed hwstETH vs Unit uETH only after hKAITO/hxSQUID books are honest.

**Phase D — C1 hVIRTUALMAX**
Same Base stack, Virtuals Auto Max-lock. Do not enable protocol redeem.

**Phase E — NestVault v2 (optional redeploy)**
Verified compound 1% + EpochGate mint delay (PR #5). Live 10k test NEST can stay; do not migrate user funds until v2 is tested.

**Phase F — BSC / Solana**
BLUAI4Y only after Relay WHYPE fills are routine. Solana listings wait on a non-EVM lockbox.

---

## Architecture (this branch)

```
src/
  NestVault.sol / HNest.sol / HevAdapter.sol   # live-style native hNEST
  lz/
    LeafOFTAdapter.sol / LeafOFT.sol           # L
    LeafInboundLockbox.sol / LeafClosedOFT.sol # C1
    LeafRedeemQueue.sol                        # C2
    LeafYieldFee.sol                           # harvest + convertYieldToHype + pullYield
    LeafHypeRewarder.sol                       # 1% / 99% WHYPE
    HypeAddresses.sol                          # WHYPE, Wormhole HYPE, USDC BSC
    LeafSecurity.sol / LayerZeroAddresses.sol / AssetCatalog.sol
listings/catalog.json
docs/HYPE_YIELD.md
docs/wrap-kinds.md
docs/testnet-deploy.md
keeper/hypeYield.ts                            # pull → swap → notify stub
```

---

## Risk

HyperLeaf makes lock and staking risk **tradable**. It does not remove it.

- Smart-contract risk — **not externally audited**
- C1 closed tickers can trade at a persistent discount to NAV
- Keeper / harvest key can pull surplus yield, not principal — still a hot wallet; keep it small
- Points / airdrops on source stakes usually accrue to the **lockbox**, not the hToken until harvested
- LayerZero / DVN / Executor liveness
- Thin HYPE books on source chains — wrong ticker (BSC HYPE, cbHYPE) will brick the harvest
- Underlying protocol upgrades (Nest HEV, Squid StakedToken, Meteora, …)
- Deposit caps and pause are expected in the first months of each listing

---

## Develop

```bash
git clone -b feat/lz-oft-wrap https://github.com/HyperLeafHQ/HyperLeaf
forge test
```

Wrap tests: `test/lz/` (including `LeafHypeRewarder.t.sol`). Native tests: `test/NestVault.t.sol`.

Deploy wrap: `script/lz/` (`DeployTestnetSource`, `DeployTestnetDest`, `WirePeers`, `DeployHypeRewarder`, `SetSecurityStack`).

Set `OWNER` / `GUARDIAN` to **your** wallets before any mainnet broadcast. Do not leave a bot as owner. Set `FEE_RECIPIENT`. Set `harvester` to a key that can only `pullYield`, not `setPeer`.

---

## License

MIT
