# HyperLeaf

**Liquid staking infrastructure for HyperEVM.**

Hyperliquid already has deep markets and native HYPE staking. HyperLeaf brings the rest of the yield-bearing world to HyperEVM: locked governance, duration stakes, LSTs, and other productive positions that are otherwise difficult to trade or use as collateral.

HyperLeaf turns a productive position into a **Leaf** ticker on HyperEVM. The Leaf represents that specific economic claim — principal, yield, and any lock or withdrawal conditions remain part of the asset. Newly realized staking surplus is paid out as **HYPE**, while the Leaf can be used across the HyperEVM ecosystem as a normal token.

> HyperLeaf does not remove lock or staking risk. It makes otherwise hidden or illiquid claims easier to use.

> **HyperLeaf does not provide liquidity. It provides infrastructure for markets around otherwise illiquid claims.**

App: [hyperleaf.finance](https://hyperleaf.finance) · X: [@HyperLeafHQ](https://x.com/HyperLeafHQ)

**Current status:** hNEST is live on HyperEVM (999), with a deliberately small cap. The L/C1/C2 wrap listings in this repository are development / rollout work and are not all deployed. **Contracts are not externally audited. Do not deposit funds you cannot afford to lose.**

---

# Part I — For users and the ecosystem

## For holders

You may already own something that earns — xSQUID, cbETH, a long-duration farm position, veNEST, or another productive receipt. On its home chain, that position may be locked, thinly traded, or difficult to use as collateral.

HyperLeaf gives that specific position a representation on HyperEVM:

| You get | You do not get |
| --- | --- |
| A HyperEVM ERC-20 for that **specific** claim | A generic wrapped copy of the spot token |
| The underlying economic state: principal, yield, and lock conditions | A promise that every ticker exits 1:1 at any time |
| Staking surplus distributed in HYPE | A guarantee of liquidity |
| A token that other HyperEVM protocols can integrate | HyperLeaf taking directional market risk for you |
| An exit path for claims that cannot currently be unstaked | An AMM or treasury that guarantees the other side |

Protocol revenue is **1% of realized staking yield** on supported yield flows. Locking and unlocking are not charged a protocol fee. Exact economics depend on the listing design.

### Backed, redeemable, liquid, fungible

These are deliberately different properties:

| Term | Means | Does not mean |
| --- | --- | --- |
| **Backed** | Realizable underlying exists for the supply | You can exit at NAV immediately |
| **Redeemable** | The listing has a supported path home | The HyperEVM market is deep |
| **Liquid** | There is a market participant willing to trade | HyperLeaf guarantees a 1:1 exit |
| **Fungible** | One ticker represents one defined economic claim | Every listing has identical exit mechanics |

A listing may trade below NAV when the underlying position has a lock or withdrawal delay. That discount can be a liquidity price rather than a loss of backing. HyperLeaf does not promise a buyer or an NAV floor.

## For HyperEVM protocols

The long-term goal is simple: another protocol should be able to say **“we support Leaf assets.”**

A Leaf is a normal HyperEVM token, but integrations should understand the listing's economics before using it:

- A listing can be instant-redeemable, queued, or market-exit only.
- C1 / market-exit assets should be priced from their actual market, not assumed to be 1:1 with the spot token.
- Listings are isolated; one listing's pause or risk state should not become a global protocol assumption.
- A Leaf can become useful collateral, LP inventory, or margin collateral once its market and risk parameters are understood.

HyperLeaf does not run a trading vault and does not promise to make a market. The ecosystem creates the liquidity around the asset.

## How the experience works

```text
Productive position on Base / BSC / Ethereum / HyperEVM / Solana
        │
        │  lock or escrow the specific receipt / stake claim
        │  bridge the representation
        ▼
HyperEVM Leaf ticker
        ├── use as a normal token
        ├── trade in supported markets
        ├── L: protocol redemption path
        ├── C1: market-exit path
        └── C2: queued redemption path
```

The details behind each path are technical implementation and operational policy; they are kept in Part II below and will ultimately move to the project Wiki.

## Ecosystem vision

HyperLeaf is intended to become an **ingress layer for productive assets** on HyperEVM.

The project optimizes for:

1. **Economic fidelity** — the Leaf should represent a specific underlying claim rather than pretending to be a generic spot-token wrapper.
2. **Composable markets** — once a Leaf has a real market, other protocols can use it as collateral, LP inventory, or margin.
3. **Explicit risk** — lock periods, withdrawal queues, bridge assumptions, and backing constraints should be visible rather than hidden behind a ticker.
4. **No artificial liquidity promises** — HyperLeaf does not need to become an AMM, market maker, or treasury buyer to be useful infrastructure.

---

# Part II — Technical reference (temporary; moving to Wiki)

> This section is intentionally implementation-heavy. It is kept in the README for now so the repository has one complete public technical reference. Once GitHub Wiki becomes the canonical documentation surface, this section should move there and the README should remain focused on Part I.

## Listing model

HyperLeaf uses three main wrap / exit kinds:

- **L — Liquid receipt:** a transferable receipt with a direct protocol redemption path where supported.
- **C1 — Market exit:** no protocol redemption; the Leaf is exited by matching a buyer against the claim.
- **C2 — Queued exit:** burn the Leaf, wait for the underlying protocol's exit window, then claim the source asset.

Listings do **not** share backing. The bridge path starts closed, and listing configuration is expected to carry explicit identity / security tags and supply constraints.

## Current listing order

One production listing at a time unless an already-proven adapter, bridge path, and accounting model make batching materially lower risk.

| Priority | Listing | Kind | Source | Status / rationale |
| --- | --- | --- | --- | --- |
| P0 | **hNEST** | Native | HyperEVM | Live, deliberately capped |
| P0 | **hCANARY** | L | Base | Real LayerZero canary; toy asset, not a product |
| P1 | **hxSQUID** | L | Base | xSQUID receipt; side-token rewards → HYPE |
| P1 | **hAVNT** | L | Base | Same Base L path; fixed rewards integration |
| P2 | **hgSOON** | L | BSC | `convertToAssets` rate model; never the 90-day cooldown path |
| P2+ | **hslisBNB** | L | BSC | Lista slisBNB only; after hgSOON; never native BNB / 7d unstake |
| P2 | **hsWBERA** | L | Berachain | Rate-surplus model; never the 7-day NFT queue |
| P3 | **hsAVAX** | L | Avalanche | BENQI `getPooledAvaxByShares`; no request-unlock path |
| P3 | **hLBTC** | L | Ethereum | LBTC only; 8-decimal rate; router `getRate`; jump breaker |
| P3 | **hstkwaUSDC** | L | Ethereum | `stkwaEthUSDC.v1` rate + RewardsController |
| P4 | **BLUAI4Y** | C1 | BSC | Market-exit only; Claim Board |
| P4 | **hORDER** | C1 | Arbitrum | Orderly proxy; market exit; no CREATE2 twin |
| P4+ | **hveAERO** | ve-NFT | Base | Permanent NORMAL veNFT only; dedicated NFT lockbox |
| P4+ | **hveUP** | ve-NFT | Robinhood | veUP NFT only; never liquid UP |
| P4+ | **PTSMAX** | C1 | BSC | River Pts → sRIVER_V2 NFT; specialized lockbox |
| P4+ | **hB3** | C1 | Base | Address-keyed farm; requires verified claim path |
| P4+ | **hsteakUSDC** | L | Base Morpho | ERC-4626 share only |
| P4+ | **hDAI** | L | Ethereum Morpho | Gauntlet DAI Core V1 shares; cap 100k DAI; never DAI / Blue market |
| P4+ | **hUSDT** | L | Bitway | BTWUSDT Core Alpha share; never raw USDT |
| P4+ | **hsteakUSDG** | L | Robinhood Morpho | ERC-4626 share only; never deposit/redeem USDG |
| P5 | **hJitoSOL** | L | Solana | Rate-bearing LST; stake-pool rate only; no NCN restake |
| Watch | **hUSD1** | L | BSC HertzFlow | HLV receipt only; never raw USD1; NAV can drop |
| Watch | **hbwBTW** | L | Bitway | bwBTW only; low priority |
| Watch | **hsTRX** | L | TRON | JustLend sTRX only; BLOCK until LZ TRON mainnet ULN |
| Watch | **hLINK** | C2 | Ethereum | Chainlink v0.2 pool full / 15k cap; research only |
| Watch | **hliSLVR** | L | Robinhood | Only after tax-free receipt is confirmed |
| Watch | **hTWO** | C2 | Robinhood | Requires dedicated 1h / 7d queue design |
| Watch | **hSB** | ve-NFT | Robinhood | Activated NFT only; geo and NFT lockbox constraints |
| Watch | **hANSEM** | L? | Solana | Requires StrategyAccount / omnichain-holder design |
| Watch | **hSEED** | C1 | Arbitrum | Need verified stake domain and reward path |
| Watch | **hfragSOL / hkySOL / hezSOL** | L/C2 | Solana | Jito Vault VRTs; slash + unstake queue complexity |
| Parked | **hSKY** | C1 | Ethereum | Stake-only strip / LockStake constraints |
| Parked | **hGMX** | C1 | Arbitrum | Staking economics currently not attractive / legacy path retired |
| Parked | **hUNCX** | — | Ethereum | Current reward / buyback state does not support intended economics |
| Parked | **hSNX** | — | Ethereum | Relevant pool closed; defer |
| Parked | **hLIT** | — | Lighter L2 | Stake lives on Lighter zk-rollup; integration path needs separate work |
| Hold | **hstkAAVE** | — | Ethereum | Legacy path; Umbrella route is `hstkwaUSDC` |
| Last | **hwstETH / weETH / ezETH / hcbETH** | L | — | Official weETH already on HyperEVM. ETH LST family last |
| Blocked | **hKAITO / hVIRTUALMAX** | — | Base | Need omnichain StrategyAccount / CREATE2 holder |

### Sequence

`hNEST → hCANARY → hxSQUID → hAVNT → hgSOON → hsWBERA → hsAVAX → hLBTC → hstkwaUSDC → BLUAI4Y → hORDER → specialized EVM assets → hJitoSOL → ETH LSTs last / watchlist`

See [`docs/ROADMAP.md`](docs/ROADMAP.md) and [`listings/catalog.json`](listings/catalog.json) for the detailed internal ordering.

## Yield model

The core economic rule is that the protocol takes **1% of realized staking surplus**, while approximately **99% remains attributable to Leaf holders**.

There are two broad accounting families:

### Side-token rewards

Example: a vault receives QUID or another reward token. The reward inventory can be converted to WHYPE, and the resulting HYPE is allocated through the listing's reward accounting.

### Rate-bearing receipts

Example: cbETH or another receipt whose value grows through an exchange rate. Only verified rate-implied surplus is harvestable. Principal is not treated as yield merely because the token balance changed.

The implementation must also account for donations, downward rate movement, rate recovery, rounding, and transfer-time reward ownership. A rate drop followed by a recovery must not manufacture a new protocol fee from a zero-net round trip.

## hNEST

hNEST is the native HyperEVM product:

`NEST → NestVault → veNEST / HEV → hNEST`

NEST remains on HyperEVM. hNEST is capped, and withdrawals follow Nest / HEV liquidity and unlock windows rather than promising instant 1:1 redemption.

Current HyperEVM 999 contracts:

| Contract | Address |
| --- | --- |
| NestVault | `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` |
| HNest | `0x2101621F51D7E05518D6680C62d04Ad47bC4e05D` |
| HevAdapter | `0xc89273ACB22a4e1df81A396FE0Bf6eD6E2CA6fD2` |
| NEST | `0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035` |

## Claims / C1 market

C1 assets do not have a protocol redemption path. The Claim Board matches an owner of a Leaf claim with a buyer who intends to acquire the underlying economic position.

Important invariants:

- No treasury bid and no implied 1:1 floor.
- Price can differ from NAV because of liquidity and remaining lock time.
- Cross-chain fulfillment should be tied to the source-side paid / settlement event, not simply to a destination-side message arrival.
- User principal and reward accounting must remain separate from the market's buyer incentive.

Details: [`docs/CLAIM_MARKET.md`](docs/CLAIM_MARKET.md).

## Cross-chain architecture

LayerZero V2 is the message layer for the EVM wrap flow. The system is designed around explicit listing identity, peer configuration, bridge-open state, per-transaction / daily limits, and inner-supply / health constraints.

The intended shape is:

```text
Source position
    │
    ├── lock / escrow exact claim
    │
    └── LayerZero message
             │
             ▼
       HyperEVM Leaf
             │
             ├── L redemption
             ├── C1 market exit
             └── C2 queued exit
```

The bridge is expected to remain closed until configuration, peers, limits, supply ceilings, and operational tests are verified.

## Permissionless harvesting

Harvesting low-value or high-frequency rewards should not require the protocol to predict whether a token is “worth it.” The preferred architecture is:

`StrategyAccount → RewardAdapter → RewardManager → SettlementExecutor`

A permissionless caller can pay gas to trigger a safe harvest. The contracts validate approved targets, selectors, accounting rules, and destination bindings. Swap / bridge execution remains separately constrained until its destination and route are fully bound.

For strategies whose eligibility depends on an address on another chain, the StrategyAccount is an execution identity rather than the economic owner:

`Vault → StrategyAccount → stake / participate → snapshot → claim → bridge → settle → Vault`

Rewards should be assigned by campaign / epoch snapshot rather than simply to whichever account holds current shares when the reward arrives.

## Solana

Solana listings require chain-specific lockbox and accounting rather than pretending the EVM `LeafOFTAdapter` model is reusable as-is.

The first Solana target is **hJitoSOL**. The model is a rate-bearing LST where the Solana program is responsible for exact share / asset math and 1% yield extraction. Follow-ons include jupSOL, mSOL, and INF after hJitoSOL proves the lockbox path.

Jito Vault VRTs and long-window Solana claim assets come later because their slash, queue, or reward mechanics require a different risk model.

The current spec crate is [`solana/leaf-jito-rate`](solana/leaf-jito-rate), with operational notes in [`docs/GROK_BOT_SOLANA.md`](docs/GROK_BOT_SOLANA.md).

## Security and trust model

HyperLeaf is **not trustless today**.

Current deployments still use owner / guardian / keeper powers for operations such as pausing, changing certain adapters and execution configuration, reward routing, and emergency recovery. This is a deliberate early-stage trade-off for unaudited software and capped TVL.

The project's public admin-reduction plan is tracked in [Trustless Roadmap #6](https://github.com/HyperLeafHQ/HyperLeaf/issues/6).

The governing principle is:

> **Prefer a hard-coded constraint over an admin promise.**

The roadmap moves through multisig custody, hard-coded caps, timelocked fund-affecting operations, allowlisted external calls, and eventually independent emergency governance.

## Known implementation constraints / audit topics

The following are active engineering and audit topics rather than claims that the system is fully trustless:

- Admin-controlled external-call configuration must not silently expand beyond safe selectors / destinations.
- Live rewarder replacement or disable / re-enable must not replay historical reward accounting.
- Farm integrations should verify exact principal consumption; a partial stake call must not make remaining idle principal appear harvestable.
- Pause semantics should distinguish asset-release operations from unwind / recovery messages.
- Live farm / strategy configuration should be frozen or migrated explicitly once user funds are deposited.
- Emergency `abortCredit` scope should be constrained to a declared rescue path or a specific pending credit.
- Rate-accounting must handle downward movement and recovery without manufacturing yield.

These items are tracked in the repository's security reviews and should be considered before materially increasing TVL.

## Deployment / operator references

For implementation and operations:

| Topic | Reference |
| --- | --- |
| Wrap kinds | [`docs/wrap-kinds.md`](docs/wrap-kinds.md) |
| Claim Board | [`docs/CLAIM_MARKET.md`](docs/CLAIM_MARKET.md) |
| Yield → HYPE | [`docs/HYPE_YIELD.md`](docs/HYPE_YIELD.md) |
| Solvency | [`docs/SOLVENCY.md`](docs/SOLVENCY.md) |
| Peg / backing | [`docs/PEG.md`](docs/PEG.md) |
| Trust assumptions | [`docs/TRUST.md`](docs/TRUST.md) |
| Asset order | [`docs/ROADMAP.md`](docs/ROADMAP.md) |
| Listing catalog | [`listings/catalog.json`](listings/catalog.json) |
| Operator / keys | [`docs/OPERATOR.md`](docs/OPERATOR.md) |
| EVM mainnet rollout | [`docs/GROK_BOT_MAINNET.md`](docs/GROK_BOT_MAINNET.md) |
| Solana deployment | [`docs/GROK_BOT_SOLANA.md`](docs/GROK_BOT_SOLANA.md) |
| Frontend architecture | [`docs/GROK_BOT_FRONTEND.md`](docs/GROK_BOT_FRONTEND.md) |

## Testing

The repository uses Foundry tests for the Solidity system and a dedicated Solana crate / program for Solana-specific accounting.

Before treating a listing as production-ready, the relevant test suite should cover its bridge path, exact principal conservation, reward accounting, pause / recovery semantics, and listing-specific withdrawal behavior.

```bash
git clone -b feat/lz-oft-wrap https://github.com/HyperLeafHQ/HyperLeaf
forge test
```

## Risk disclosure

HyperLeaf **markets** lock and staking risk. It does not remove it.

- Contracts are **not externally audited**. Implementation may include AI-assisted code and should not be treated as a substitute for independent security review.
- Some listings can remain below NAV for extended periods because of lock duration or thin liquidity.
- HyperLeaf does not guarantee a buyer, a market, or a 1:1 exit for C1 assets.
- Source protocols can change their staking, withdrawal, or reward mechanics.
- Cross-chain delivery, bridge configuration, and external integrations introduce additional operational risk.
- Early listings are intentionally capped, pausable, and sequenced one at a time.

---

## Documentation status

**README Part I** is the intended public-facing narrative for users and the HyperEVM ecosystem.

**README Part II** is the current technical reference and is intended to move to GitHub Wiki once Wiki editing is available through the project's tooling. Until then, it remains here so technical details, rollout order, and risk assumptions are publicly visible in one place.

## License

MIT
