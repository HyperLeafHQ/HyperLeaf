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

Testnet copy-paste: [`GROK_BOT_TESTNET.md`](GROK_BOT_TESTNET.md). Do not set `INNER_TOKEN` to live xSQUID / cbETH / BLUAI. Skip `SetSecurityStack` on HyperEVM testnet.

## Invariant (merge gate)

```
outstanding Leaf claims  ≤  economically realizable underlying
                           (principal + booked yield − pending redemptions − fees)
```

Not `balanceOf(lockbox)`. Principal is never harvested as yield. A burn drops liabilities before assets leave. A PR that cannot show this still holds does not merge.

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
