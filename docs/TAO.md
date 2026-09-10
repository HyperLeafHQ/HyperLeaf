# TAO — park. No live EVM LST

Verified 2026-09-10 against official docs and chain. Not from eval #06.

## Gate 0

Yield lives on **Bittensor Subtensor**, not Ethereum.

Official: staking is `add_stake` / `remove_stake` on a subnet AMM. Position is `(hotkey, coldkey, netuid)`. Not an ERC-20. [Staking and pools](https://www.bittensor.com/docs/concepts/staking-pools).

Bittensor EVM is **chain 964** (Finney), not Ethereum. “EVM smart contracts are executed solely on the Bittensor blockchain.” Staking precompile V2: `0x0000…0805`. [docs](https://docs.bittensor.com/evm-tutorials/staking-precompile).

## What exists on Ethereum (do not wrap)

| Token | Address | Live | Why not |
| --- | --- | --- | --- |
| **wTAO** | `0x77E06c9eCCf2E797fd462A92B6D7642EF85b0A44` | ~110,758 (9 dp). Spot wrap. Closed-source custodial. **No stake.** Issuer said staking would only incentivize bridging back. |
| **tTAO** | `0xE4887Cf30fF3EDb843369f2161FCB7e064ff28f0` | ~2,555. Tensorplex bridge IOU. |
| **stTAO** | `0xB60acD2057067DC9ed8c083f5aa227a244044fD6` | ~6,276 leftover. Tensorplex LST. |

Tensorplex Stake & Bridge: **deprecated**. Official: no new deposits; burn + manual SS58 withdraw, monthly. Accelerated for cybersecurity. [docs](https://docs.tensorplex.ai/tensorplex-docs/tensorplex-stake-and-bridge-deprecation-phase). They point leftover stakers to backprop.finance (analytics / native stake UI), not a new ERC-20.

## Could we “just stake it ourselves”?

Only on chain 964, via the precompile, holding a hotkey. That is **being Tensorplex**, not wrapping a receipt. They just shut that product down.

LZ is live on Subtensor EVM (`eid` **30374**). A later lockbox could theoretically `add_stake` root (SN0, TAO-denominated) and OFT to HyperEVM. Still:

- Stake is a pallet position, not a token in the lockbox
- Unstake is an AMM swap (slippage)
- Validator take / subnet vs root
- Coldkey custody

Do not start this before hJitoSOL. Do not start it to compete with native `btcli stake add`.

## Capture

Wrapping wTAO / tTAO / stTAO: **0 yield**. Native root/subnet emissions: only if we run the Subtensor position.

## Status

`parked`. Revisit only if a **live**, non-custodial, transferable LST exists on an EVM we already speak, or we explicitly take on chain-964 custody (product decision, not a listing).
