# hJitoSOL — first Solana listing

Not this Grok-bot pass (batches 0–4 stay EVM). Dest OFT: `BATCH=5 ASSET=hjitosol`. Source is a **new Solana program**, not `LeafOFTAdapter`.

jupSOL / mSOL / bnSOL / INF are **not this listing**. Do not start them until hJitoSOL lock/unlock/harvest has run on mainnet.

## What we wrap

| | |
| --- | --- |
| Mint | `J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn` (JitoSOL, 9 dp) |
| Pool | `Jito4APyf642JPZPx3hGc6WWJ8zPKtRbRs4P815Awbb` (read-only) |
| Dest | HyperEVM `LeafOFT` `hJitoSOL`, 18 dp. `shares = atoms * 1e9` |
| LZ | eid **30168** → 30367. Receive confirmations **32**. Peer = 32-byte PDA (`WireSolanaPeer`) |
| Tag | `keccak256("hjitosol")` = `0xb107d7c3…a40e` |

Never wrap SOL. User who wants SOL: unwrap hJitoSOL → JitoSOL, then Jito.

## Yield we **do** capture

JitoSOL quantity does not grow. SOL-per-token does (staking + MEV/TOV already in the pool). Same 1% retain skim as hcbETH. Math: `LeafJitoRate` / `solana/leaf-jito-rate`.

```
surplus = lastAccounted * (rate - lastRate) / rate
fee     = 1% of surplus   → harvest ATA → later WHYPE
99%     stays as remaining JitoSOL in the PDA
```

## Yield we **do not** capture: NCN / restaking

There **is** a receipt if you deposit into NCN vaults. It is a **Vault Receipt Token (VRT)**, not JitoSOL:

| VRT | Issuer | Mint | Notes |
| --- | --- | --- | --- |
| **fragSOL** | Fragmetric | `FRAGSEthVFL7fdqM8hxfxkfCZzUvmg21cqPJVvC1qdbo` | Switchboard path. Token-2022 + transfer hooks |
| **kySOL** | Kyros | `kySo1nETpsZE2NWe5vj2C64mPSciH1SppmHb4XieQ7B` | TipRouter-class vault. Unstake = enqueue + epoch |
| **ezSOL** | Renzo | `ezSoL6fY1PVdJcJsUpe5CM3xkfmy3zoVCABybm5WtiC` | Same Jito Vault program |

Watchlist tickers: `hfragSOL` / `hkySOL` / `hezSOL`. **Not this listing.** Slashing is per-NCN (operator misbehavior). Withdrawal is a ticket, not instant. A restaked product is a different solvency row (VRT + slash + queue), never “turn on restake” inside hJitoSOL.

Frontend must say this was a choice: [`GROK_BOT_FRONTEND.md`](GROK_BOT_FRONTEND.md) § Why hJitoSOL.

Holding JitoSOL in the PDA is **not** (re)staking.

| Source | Lands in our PDA? | Why |
| --- | --- | --- |
| Stake-pool rate (inflation + TOV tips already in JitoSOL/SOL) | **Yes** — this is the listing | Read pool account. No CPI |
| Token airdrop / snapshot to JitoSOL **token-account holders** (JTO-style) | **Yes, if they push to the ATA** | `harvest_other(mint)` on the PDA's ATA for that mint. 1% then WHYPE. Never this path for JitoSOL itself |
| Merkle / claim program that must be called | **Not this version** | Same class as KING merkle: wrong ABI. Pin a claim later if a real campaign needs it |
| **Switchboard NCN** (`BGTtt2wd…`) SWTCH | **No** | Must deposit JitoSOL into Fragmetric / a Jito **Vault** (VRT). Rewards go to vault ATA. Slashing. |
| **TipRouter NCN** extra 0.15% to JitoSOL *(re)stakers* | **No** | Same: vault deposit. The pool's own TOV share is already in the rate (row 1) |
| Other NCNs (DePHY, …) | **No** | Vault |

We **never** CPI:

- SPL stake pool `SPoo1Ku8…` (`depositSol` / `withdrawSol` / `depositStake`)
- Interceptor `5TAiuAh3…`
- Vault `Vau1t6sL…`
- Restaking `RestkWeA…`

NCN TVL is small vs the stake pool. Missing SWTCH is accepted. Do not "turn on restake later" on this listing — that would change backing from JitoSOL to a VRT + slash risk. A restaked product is a **different ticker**.

## Message

```
abi.encode(listingTag, bytes32(to), uint256 shares)  // 96 bytes, not Borsh
```

## Program (state machine is `solana/leaf-jito-rate/src/lockbox.rs`)

`lock` / `unlock` / `harvest_rate` / `harvest_other` / `halt`. `cargo test --manifest-path solana/leaf-jito-rate/Cargo.toml`.

Constants: `src/lz/LeafJitoPolicy.sol`.
