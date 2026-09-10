# $M / MemeCore — watch (2026-09-11)

Do **not** wrap native $M. Consensus stake is `stakeM` on the validator system contract (`0x1234…0002`). Docs mention an `X$M` receipt; **no official ERC-20 address** is published. Undelegate lock is not pinned.

Do **not** wrap:

- BSC `M` `0x22b1…31fa` — bridged ticker, 18-dec, **not** an LST. HyperEVM empty. MemeCore empty at that address.
- MemeX **stM** — 1:1 XP / launchpad, not block-reward stake.
- MRC-20 / meme-coin delegation (`stakeMeme`) — PoM, not $M.

Official: chain **4352**, RPC `https://rpc.memecore.net`, native 18-dec $M.

LayerZero **eid 30466** is live (EndpointV2 `0x6F47…Dd5B`). Metadata DVNs on that chain are Labs + Nethermind + DeadDVN. **No Horizen, no Canary.** Our 2-of-3 stack cannot be set. Nethermind is not in the stack.

Watch until (1) official transferable **X$M** (or equivalent LST) address, (2) Labs+Horizen+Canary on 30466. Then L-wrap the receipt, never `stakeM` / undelegate from the lockbox.

`NotThisBatch`.
