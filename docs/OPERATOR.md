# Operator & deploy notes

Not for users. README is the public product. This file is for whoever broadcasts.

## Keys

| Role | Can | Must not |
| ---- | --- | -------- |
| **OWNER** | `setPeer`, caps, pause/unpause, harvest config, ownership | A bot, a shared laptop, the harvester key |
| **GUARDIAN** | `pause` | Unpause, setPeer, pullYield |
| **HARVESTER** | `pullYield` | `setPeer`, ownership, pause policy |
| **CONVERTER** | Receive pulled surplus for swap → WHYPE | Custody of the lockbox |
| **FEE_RECIPIENT** | 1% of yield | User deposits |

Set these to **your** wallets before any mainnet broadcast. Do not leave a grok bot as owner. Four different EOAs.

## Peg (do this before mint)

See [`PEG.md`](PEG.md). Liquid 7 Sep 2026: unbacked receipts took a real peg-out.

1. `setListingTag` (frozen). Same tag on source and OFT.
2. `setLimits(maxPerTx, maxPerDay)` and OFT `setSupplyCap` = source `depositCap`.
2b. Source `setInnerSupplyCeiling` to a number **above** today's `inner.totalSupply()` with headroom for honest mint, not a flash print.
3. Wire peers. Mainnet: `SetSecurityStack` (2-of-3 + HyperLeaf required DVN).
4. Read the live config on-chain. Then `openBridge` on **both** sides.
5. Guardian is a different key. `closeBridge` pauses and keeps mint closed after unpause.

Do not `openBridge` from a bot. A merged PR is not an open bridge.

## Invariant (merge gate)

```
outstanding Leaf claims  ≤  economically realizable underlying
                           (principal + booked yield − pending redemptions − fees)
```

Not `balanceOf(lockbox)`. Principal is never harvested as yield. A burn drops liabilities before assets leave. Fill [`SOLVENCY.md`](SOLVENCY.md) for that ticker. A PR that cannot show this still holds does not merge.

## Branches

| What | Where | Deployed? |
| ---- | ----- | --------- |
| Live hNEST | `main` | HyperEVM 999, capped |
| Wrap L/C1/C2 + yield → HYPE | `feat/lz-oft-wrap` · [PR #4](https://github.com/HyperLeafHQ/HyperLeaf/pull/4) | No |
| NestVault v2 (verified compound + EpochGate) | `feat/hnest-yield-fee-gate` · [PR #5](https://github.com/HyperLeafHQ/HyperLeaf/pull/5) | No |

`main` is the live NestVault only. HYPE conversion is the wrap branch until PR #4 merges.

## HyperEVM 4626 + CoreWriter

Official HyperEVM vaults: ERC-4626 + CoreWriter (`0x3333…`) + L1Read (`0x0800+`). Useful **after** a Leaf ticker has a book (link Core spot, `oraclePx` for HYPE). Not for Ethereum/Base custody. Not for turning a lockbox into an HLP-style book. Dest tokens stay OFTs.

## Develop

```bash
git clone -b feat/lz-oft-wrap https://github.com/HyperLeafHQ/HyperLeaf
forge test
```

Wrap tests: `test/lz/`. Native: `test/NestVault.t.sol`.
Deploy: `script/lz/` (`DeployTestnetSource`, `DeployTestnetDest`, `WirePeers`, `ConfigureTestnetListing`, `SmokeTestnetSend`, `SmokeTestnetRedeem`, `DeployHypeRewarder`, `SetSecurityStack`).
