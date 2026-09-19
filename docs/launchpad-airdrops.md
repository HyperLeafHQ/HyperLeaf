# Launchpad airdrops (Virtuals, later Ansem)

Income is **agent/launch tokens**, not the inner LST rate.

## What a “claim tx” is

Not unwrap. A merkle distributor, one per launch:

`claim(uint256 index, address account, uint256 amount, bytes32[] proof)` = `0x2e7ba6ef`

Base example: `0xee45c4…b75c` → distributor `0xaec7971f…` paid ~44.03 NOVER, `account` = the ve holder. Robinhood example: `0xa941a3…13dc` (chain 4663, distributor `0x109c9fa8…`).

`pokeMerkleClaim` submits this **as the lockbox** (account is forced to `address(this)`). Owner allowlists the distributor; anyone pokes; then `pullYield` / holder `sweep` to the converter. Do **not** set `0x2e7ba6ef` as `rewardsSelector` — that path encodes `(this, max)`.

## Rules (v1)

1. **Canonical-endpoint EVMs (ETH / Base / Arb / BSC).** CREATE2 the lockbox with the same initcode so extra-chain merkle hits the same address. Twin: **do not `openBridge`**. Robinhood endpoint is not `0x1a44…` — lockbox address will not match; skip RH dust.
2. **Filter dust.** 6–7 launches/day, most go to zero. Do not allowlist a distributor unless an off-chain quote says the allocation covers gas + keeper time. Low TVL ⇒ skip almost everything.
3. **Never auto-swap unknown tokens to HYPE.** Tax/honeypot. `pullYield` only after a human (or a strict allowlist) marks the ERC-20 as sellable.
4. **Robinhood gas** can make even a “real” drop negative EV. Don’t poke there blindly.
5. Merkle proofs come from Virtuals’ API, not the chain. Keeper job, not a Solidity loop.

hVIRTUALMAX still ships as C1 (never redeem, Auto Max-lock). We do **not** market “we catch every agent airdrop.” Merkle poke is pins-landing. **Not a BATCH — no GO.**

## Ansem

Same product shape on Solana (`ansem.io`: launches airdrop to `$ANSEM` holders). Watchlist only — no EVM lockbox in this repo.
