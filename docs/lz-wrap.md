# Hyperleaf wrap — LayerZero OFT (no Relayer / no VPS)

Multi-asset lock-and-mint. Users pay LayerZero Executor. Hyperleaf does not run a 24h mint bot.

Kinds: **L** instant receipt, **C1** market-only (BLUAI4Y), **C2** delayed official redeem. See `docs/wrap-kinds.md`.

## What you prepare

You do **not** need a VPS to go live.

| Thing | What it is | Need now? |
| ----- | ---------- | --------- |
| Owner wallet | Admin. Hardware wallet. Set `OWNER` to this from deploy day one. | Yes |
| Guardian wallet | Emergency pause. Different device. | Yes |
| ETH on Base / BNB on BSC + HYPE on HyperEVM | Deploy gas | Yes |
| Executor | LayerZero mailman. User pays ~$0.25+/send | No setup |
| DVN | Notaries. 2-of-3: LZ Labs, Nethermind, Horizen | Script sets them (Base/HyperEVM). BSC: fill from LZ metadata |
| Hyperleaf DVN veto | Your extra notary | **Not at launch** |
| VPS | Always-on PC | Only later if you run your own DVN |

Executor = mailman (LayerZero). DVN = notary. Google Cloud is on Base but not HyperEVM, so it is not in the 2-of-3. Your required DVN blocks fakes and also blocks everyone if offline — do not set HYPERLEAF_DVN until a real DVN worker exists on both chains.

## Deploy

See `script/lz/`. L: `DeployAdapter` + `DeployOFT`. C1: `DeployClosed`. C2: `DeployQueued`. Then `WirePeers` + `SetSecurityStack`.

One lockbox per inner token. Never two lockboxes for the same token. Never enable reverse send on a C1 pair.
