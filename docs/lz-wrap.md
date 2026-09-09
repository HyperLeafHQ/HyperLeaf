# Hyperleaf wrap — LayerZero OFT (no Relayer / no VPS)

Multi-asset lock-and-mint. Users pay LayerZero Executor. Hyperleaf does not run a 24h mint bot.

Kinds: **L** instant receipt, **C1** market-only (BLUAI4Y), **C2** delayed official redeem. See `docs/wrap-kinds.md`.

## What you prepare

You do **not** need a VPS to go live.

| Thing | What it is | Need now? |
| ----- | ---------- | --------- |
| Owner wallet | Admin. Hardware wallet. Set `OWNER` to this from deploy day one. | Yes |
| Guardian wallet | Emergency pause. Different device. | Yes |
| Fee recipient | 1% of new staking yield. Set `FEE_RECIPIENT` (defaults to `OWNER`). | Yes |
| ETH on Base / BNB on BSC + HYPE on HyperEVM | Deploy gas | Yes |
| Executor | LayerZero mailman. User pays ~$0.25+/send | No setup |
| DVN | Notaries. 2-of-3: LZ Labs, Horizen, Canary | Script sets them (Base/HyperEVM/BSC/Bera). Nethermind left 2026-08-19. |
| Hyperleaf DVN veto | Your extra notary | **Not at launch** |
| VPS | Always-on PC | Only later if you run your own DVN |

Executor = mailman (LayerZero). DVN = notary. Google Cloud is on Base but not HyperEVM, so it is not in the 2-of-3. Your required DVN blocks fakes and also blocks everyone if offline — do not set HYPERLEAF_DVN until a real DVN worker exists on both chains.

## Fees

No protocol fee on deposit or redeem. Users pay LZ messaging + gas.

- Convert **off**: 1% of newly accrued inner yield (`YIELD_FEE_BPS = 100` in `LeafYieldFee`) stays as inner, sent to `feeRecipient`.
- Convert **on**: side-token surplus → converter → WHYPE; **1% protocol / 99% holders at `notify`**. Rate-bearing L (hcbETH) with `retainRateYield` pulls **1% of** `(lastAccounted * (rate - lastRate)) / rate`. 99% stays in the box. Principal stays.

`harvest()` / `harvestToken()` are permissionless; no new yield → no extra fee.

## Deploy

See `script/lz/`. L: `DeployAdapter` + `DeployOFT`. C1: `DeployClosed`. C2: `DeployQueued`. Then `WirePeers` + `SetSecurityStack`.

Env: `OWNER`, `GUARDIAN`, `FEE_RECIPIENT` (optional, defaults to owner), `INNER_TOKEN`, `DEPOSIT_CAP`, `REDEEM_DELAY` (C2).

One lockbox **address** per inner token. Never two lockboxes for the same token. Never enable reverse send on a C1 pair.

hORDER is **Arbitrum only**. One lockbox address is the Orderly identity. Do not
CREATE2 a Base/OP twin and do not `openBridge` a second source into the same
dest OFT (double-count `ledgerPrincipal`). `DeployOmnichainLockbox` is kept
for a future listing that actually needs twins. Principal (staked ORDER),
occupancy (VALOR/esORDER), and harvest (USDC → HYPE) stay separate.
