# VVV Adapter Framework

Verification-stage implementation skeleton for Venice VVV staking, aligned to the live Base StakingV2 ABI.

## Intended flow

```text
Base VVV
  ↓ approve
StakingV2 proxy 0x321b...
  ↓
sVVV / staking claim
  ↓
VVVStakingAdapter
  ↓
Strategy Vault
  ↓
canonical bridge boundary
  ↓
hVVV on HyperEVM
```

## Source-side constants

- VVV on Base: `0xacfE6019Ed1A7Dc6f7B508C02d1b04ec88cC21bf`
- sVVV / Staking proxy: `0x321b7ff75154472B18EDb199033fF4D116F340Ff`
- Current StakingV2 implementation: `0xe37A7920dbc11253ac6d031C29f592f71B348DCA`
- Staking owner / Safe: `0x2D8CB8DC596daD0e1E34E2042E7ae6Df93B11524`

Production must read and verify these values onchain again.

## Live ABI corrections

The live StakingV2 interface uses:

```text
stake(address recipient, uint256 amount)
initiateUnstake(uint256 amount)
finalizeUnstake()
claim()
claimAndStake()
balanceOf(address)
pendingRewards(address)
stakes(address) -> rewardDebt, cooldownEnd, cooldownAmount
cooldownDuration()
```

The earlier placeholder methods `stakedBalance`, `unstake`, and `claimRewards` are not part of the live StakingV2 ABI and must not be used.

## Adapter responsibilities

1. bind exact VVV + StakingV2 addresses;
2. deposit into `stake(address(this), amount)`;
3. report verified sVVV principal plus only economically realizable pending rewards;
4. claim rewards through `claim()`;
5. expose `cooldownEnd` / `cooldownAmount`;
6. model withdrawal as initiate → cooldown → finalize, not instant exit;
7. enforce solvency against Leaf liabilities;
8. monitor implementation upgrades and Safe admin changes;
9. never treat DIEM as VVV backing;
10. never treat VVV market-price appreciation as staking yield;
11. keep Venice buyback/burn separate from claimable staking rewards.

## Production blockers

- exact proxy storage layout;
- current Safe threshold and owner set;
- fork verification of reward accounting;
- exact canonical LayerZero / HyperEVM route, if any;
- bridge mint/burn authorization and supply conservation.

## Required tests

- stake / claim / claimAndStake;
- initiateUnstake / cooldown / finalizeUnstake;
- reward accrual and emission-rate change;
- locked sVVV → DIEM mint/burn/unlock;
- `veniceEmissionsPercentageWhenLocked` behavior;
- upgrade simulation;
- Safe/admin change monitoring;
- donation and rounding handling;
- bridge mint/burn authorization;
- replay protection;
- source/destination supply conservation;
- `totalLeafLiability <= verified NAV` invariant.

This is **not deployment-ready code** until the remaining blockers are independently verified.
