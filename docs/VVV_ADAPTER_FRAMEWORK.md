# VVV Adapter Framework

This is a verification-stage implementation skeleton for Venice VVV staking.

## Intended flow

```text
Base VVV
  ↓ approve
Venice Staking Contract
  ↓
staked VVV / sVVV claim
  ↓
VVVStakingAdapter
  ↓
Strategy Vault
  ↓
canonical bridge boundary
  ↓
hVVV on HyperEVM
```

## Source-side constants from Venice official FAQ

- VVV on Base: `0xacfE6019Ed1A7Dc6f7B508C02d1b04ec88cC21bf`
- Staking contract returned by VVV `owner()`: `0x321b7ff75154472B18EDb199033fF4D116F340Ff2`
- Staking owner: Safe multisig `0x2D8CB8DC596daD0e1E34E2042E7ae6Df93B11524`

These addresses are reference data only. Production deployment must read and verify them onchain again.

## Adapter responsibilities

1. bind the exact VVV token and staking contract;
2. deposit VVV into the staking contract;
3. report economically realizable staked NAV;
4. harvest VVV rewards;
5. expose unstake/cooldown state;
6. enforce solvency against Leaf liabilities;
7. detect abnormal rate/reward changes;
8. never treat DIEM as VVV backing;
9. never treat VVV market-price appreciation as staking yield;
10. keep buyback/burn economics separate from claimable rewards.

## Not deployment-ready

The interface contains verification placeholders for `stakedBalance`, `pendingRewards`, and `claimRewards`. These method names and return semantics MUST be checked against the live Base implementation before compilation/deployment. The adapter intentionally does not contain bridge code or Leaf minting logic yet.

## Required tests

- stake / unstake;
- 7-day cooldown;
- reward accrual;
- reward claim;
- emission-rate change;
- downward rate / loss handling;
- donation handling;
- rounding;
- DIEM lock interaction;
- multisig/admin changes;
- bridge mint/burn authorization;
- replay protection;
- source/destination supply conservation;
- `totalLeafLiability <= verified NAV` invariant.
