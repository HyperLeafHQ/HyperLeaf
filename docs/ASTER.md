# ASTER C1 — blocked on-chain. Stake is the Aster **account**, not BSC

Verified 2026-09-10.

## What you asked

Take BSC ASTER in, **max-lock**, C1 ticker (sell on Leaf Market only). Same shape as `LeafVirtualsLockbox` (104w auto) / BLUAI4Y.

## Why we cannot ship that lockbox yet

Official staking is **Aster Chain account Spot**, not a BEP-20 `stake()`.

- Docs: connect wallet → pick validator → amount from **Spot balance** → lock 26–**208 weeks**. [how it works](https://docs.asterdex.com/aster-chain/staking/how-staking-works)
- veASTER is a **weight**, not a transferable token. Early exit penalty up to 60%.
- Official [contracts](https://docs.asterdex.com/overview/smart-contracts): Deposit Bridge + asTokens. **No staking/ve contract.**
- Loyalty Power = veASTER × **trading-volume boost**. A silent lockbox is 1.00×.

BSC ASTER `0x000Ae314E2A2172a039B26378814C252734f556A` is only the deposit asset. `LeafInboundLockbox._afterDeposit → stake(amt, 208, true)` has **nothing to call**.

Do not wrap idle ASTER as C1 (0 yield, 4y illiquid). Do not fake a farm selector.

## What would make C1 real

1. Aster publishes a permissionless staking contract (or EVM precompile) we can `delegate(validator, amount, 208w)` from a lockbox, **or**
2. You accept **custodial** path: Deposit Bridge `0x128463…` → Aster Spot → API stake. That is an EOA/account, not `LeafVirtualsLockbox`. Same class as parked sKAITO custody.

Until (1): **skip hASTER**. Keep **asBNB** later after hslisBNB.

`NotThisBatch`. No Solidity until the stake selector is on-chain.
