# Launchpad airdrops (Virtuals, later Ansem)

Income is **agent/launch tokens**, not the inner LST rate.

## What a “claim tx” is

Not unwrap. A merkle distributor, one per launch:

`claim(uint256 index, address account, uint256 amount, bytes32[] proof)`

Base example: `0xee45c4…b75c` → 44 NOVER to the ve holder. Robinhood example: `0xa941a3…13dc` (chain 4663).

`pokeClaim` can submit this **as the lockbox** on the chain where the lockbox lives.

## Rules (v1)

1. **Base only.** ETH / Arb / Robinhood need the same CREATE2 holder as hKAITO. Skip until then.
2. **Filter dust.** 6–7 launches/day, most go to zero. Do not allowlist a distributor unless an off-chain quote says the allocation covers gas + keeper time. Low TVL ⇒ skip almost everything.
3. **Never auto-swap unknown tokens to HYPE.** Tax/honeypot. `pullYield` only after a human (or a strict allowlist) marks the ERC-20 as sellable.
4. **Robinhood gas** can make even a “real” drop negative EV. Don’t poke there blindly.
5. Merkle proofs come from Virtuals’ API, not the chain. Keeper job, not a Solidity loop.

hVIRTUALMAX still ships as C1 (never redeem, Auto Max-lock). We do **not** market “we catch every agent airdrop.”

## Ansem

Same product shape on Solana (`ansem.io`: launches airdrop to `$ANSEM` holders). Watchlist only — no EVM lockbox in this repo.
