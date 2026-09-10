# HyperLeaf Asset Evaluation #21 — VVV / Venice AI

Status: **Selected — P1 research candidate; deployment blocked on canonical HyperEVM representation and final source-side fork verification.**

## 1. Executive conclusion

VVV passes the productive-position test. Venice has a live native staking position (`sVVV`), staking emissions, DIEM utility backed by locked sVVV, and a revenue-funded VVV buyback/burn mechanism.

Preferred architecture:

```text
VVV
 ↓
Venice StakingV2 / sVVV
 ↓
VVV Position Adapter
 ↓
Strategy Vault
 ↓
canonical cross-chain boundary
 ↓
HyperEVM hVVV
```

**Do not wrap raw spot VVV as hVVV.** The economic backing should be the verified productive staking position.

## 2. Official Venice findings

Venice's current FAQ confirms:

- Base VVV: `0xacfE6019Ed1A7Dc6f7B508C02d1b04ec88cC21bf`
- VVV `owner()` = staking contract `0x321b7ff75154472B18EDb199033fF4D116F340Ff`
- staking owner is a Safe multisig;
- emissions are observable through `emissionRatePerSecond()` and `EmissionRateUpdated`;
- staked VVV earns emissions;
- sVVV locked to back DIEM earns 80% of standard staking yield while locked;
- unstaking has a 7-day cooldown;
- DIEM is minted from locked sVVV and represents $1/day of Venice API credit when staked.

Venice's API documentation independently confirms that agents stake by calling `stake(amount)` on the Base staking contract and that the wallet's sVVV balance updates atomically. The current live contract ABI is more specific: `stake(address recipient, uint256 amount)`.

## 3. Live Base staking contract / implementation

### Proxy

- Proxy / sVVV contract: `0x321b7ff75154472B18EDb199033fF4D116F340Ff`
- Current implementation: `StakingV2` at `0xe37A7920dbc11253ac6d031C29f592f71B348DCA`
- Previous implementation observed: `0x417E7e8045aab25dcd703003dd8d7b5f2f11ead8`
- Latest recorded implementation upgrade: block `34455271`, 2025-08-20, to `0xe37A7920...B348DCA`.

The implementation exposes `UUPSUpgradeable` functions including `proxiableUUID()`, `UPGRADE_INTERFACE_VERSION()` and `upgradeToAndCall()`. The staking contract should therefore be treated as **upgradeable**, regardless of explorer UI wording that has described the proxy as EIP-1967/Transparent.

### Relevant live ABI

Read methods:

```text
ACC_REWARD_SCALE()
accRewardPerShare()
accRewardPerShareLocked()
balanceOf(address)
balanceOfUnlocked(address)
cooldownDuration()
decimals()
diem()
diemMintRates(uint256)
diemSupply(uint256)
emissionRatePerSecond()
getDiemAmountOut(uint256)
getVenicePercentage()
lastRewardTimestamp()
lockedStakes(address) -> (sVVVLockedAmount, outstandingDiemAmount)
owner()
pendingRewards(address)
stakes(address) -> (rewardDebt, cooldownEnd, cooldownAmount)
totalLockedStakedVVV()
totalSupply()
treasury()
venice()
veniceEmissionsPercentage()
veniceEmissionsPercentageWhenLocked()
```

Write methods:

```text
stake(address recipient, uint256 amount)
initiateUnstake(uint256 amount)
finalizeUnstake()
claim()
claimAndStake()
mintDiem(uint256 sVVVAmountToLock, uint256 minDiemAmountOut)
burnDiem(uint256 diemAmountToBurn)
setCooldownDuration(uint256)
setDiemMintCurve(uint256[256], uint256[256])
setEmissionRate(uint256)
setTreasury(address)
setVeniceEmissionsPercentage(uint256)
setVeniceEmissionsPercentageWhenLocked(uint256)
upgradeToAndCall(address, bytes)
```

Important correction to the first framework: there is **no** `stakedBalance()`, `unstake()`, or `claimRewards()` method in the current StakingV2 ABI. The actual flow is `balanceOf()` / `pendingRewards()` + `initiateUnstake()` / `finalizeUnstake()` + `claim()`.

## 4. Storage / accounting surface

The live ABI exposes the core storage surface needed for a HyperLeaf adapter:

- global reward accumulators: `accRewardPerShare`, `accRewardPerShareLocked`;
- reward scale: `ACC_REWARD_SCALE`;
- emission state: `emissionRatePerSecond`, `lastRewardTimestamp`;
- per-user staking state: `stakes(user)`;
- per-user locked position: `lockedStakes(user)`;
- aggregate locked principal: `totalLockedStakedVVV`;
- DIEM curve state: `diemSupply[]`, `diemMintRates[]`;
- emission split parameters: `veniceEmissionsPercentage`, `veniceEmissionsPercentageWhenLocked`;
- cooldown: `cooldownDuration`;
- external references: `diem`, `oracle`, `treasury`, `venice`.

For production, the exact Solidity storage slot map must still be captured with the verified source/build (`forge inspect ... storage-layout`) and reconciled against the proxy's EIP-1967 implementation slot. The economic state above is already exposed by the verified implementation ABI.

## 5. Admin / upgrade path

Ownership chain:

```text
VVV immutable ERC-20
      ↓ owner()
Staking proxy 0x321b...
      ↓ owner()
Safe 0x2D8CB8DC596daD0e1E34E2042E7ae6Df93B11524
      ↓
StakingV2 upgrade + emission / cooldown / treasury / DIEM parameters
```

The current Venice FAQ confirms Safe multisig control. External 2026 disclosures identify the Safe as the upgrade/emission control surface. There is an important historical inconsistency in public disclosures: the March 2026 Moonwell proposal described the Safe as **3-of-5**, while the later July 2026 token transparency filing describes the same Safe as **4-of-6** in its current control summary. Therefore HyperLeaf must read the Safe's **current threshold and owner set directly onchain** before deployment; do not hard-code either threshold from documentation.

Security implication:

- VVV token code is immutable / non-proxy;
- VVV mint authority is the staking contract;
- staking implementation is upgradeable;
- an authorized staking upgrade can therefore materially change reward, lock, cooldown, minting and accounting semantics;
- no tokenholder governance layer currently counterbalances this admin surface.

## 6. Canonical HyperEVM / LayerZero investigation

### Result: **NOT VERIFIED**

Searches of Venice's current official documentation/API documentation do **not** identify an official HyperEVM deployment or a Venice-operated LayerZero OFT route for VVV/sVVV.

Venice's current crypto-RPC documentation describes VVV staking on **Base** and lists supported RPC chains, but does not establish HyperEVM as a VVV token destination.

Public onchain evidence shows Base VVV being traded through aggregators and LayerZero/ZRO appearing as a separate asset in some routing transactions. That is **not evidence that VVV itself is a LayerZero OFT**.

HyperEVMScan currently surfaces Base VVV in multichain wallet portfolios, but that is wallet inventory metadata and does not establish a canonical HyperEVM VVV contract, authenticated mint/burn route, or sVVV bridge.

Therefore Gate 0 remains:

- Base VVV canonicality: **PASS**
- Base sVVV canonicality: **PASS**
- Official LayerZero VVV/OFT route: **NOT VERIFIED**
- Official HyperEVM VVV representation: **NOT VERIFIED**
- Third-party wrapped VVV: **FAIL / insufficient**

Production blocker: require an official/canonical route with authenticated source identity, verified destination contract, mint/burn authorization, replay protection, and source/destination supply conservation.

## 7. HyperLeaf representation

Preferred:

```text
Base VVV
 ↓
StakingV2
 ↓
sVVV
 ↓
Position Adapter
 ↓
Strategy Vault
 ↓
canonical bridge
 ↓
hVVV
```

Leaf class: **Liquid / Rate-bearing only conditionally**.

The live sVVV contract is ERC-20 and exposes `balanceOf`, `transfer`, `transferFrom`, etc., but exit is cooldown-based. HyperLeaf should not assume instant liquidity merely because sVVV is transferable.

If the final canonical cross-chain representation preserves sVVV transferability and deterministic NAV/reward accounting, Liquid / Rate-bearing is appropriate. Otherwise use a C2/C1 product model rather than forcing an LST abstraction.

## 8. Yield accounting

Separate:

1. VVV principal;
2. staking emissions;
3. 1% HyperLeaf fee on realized supported staking surplus;
4. sVVV locked as DIEM backing;
5. DIEM utility value;
6. Venice revenue-funded VVV buyback/burn;
7. VVV market price;
8. cooldown / exit liquidity.

**Buyback/burn is value capture, not an immediately claimable staking reward.**

**DIEM is a separate compute asset and must not be treated as hVVV backing.**

Core invariant:

`totalLeafLiability <= verified economically realizable NAV of productive position`

## 9. Required production tests

Before deployment:

- fork Base at a finalized block;
- verify proxy → implementation address;
- verify exact storage layout;
- verify current Safe owner set + threshold;
- stake / claim / claimAndStake;
- initiateUnstake / cooldown / finalizeUnstake;
- reward accrual before and after emission changes;
- locked-sVVV / DIEM mint and burn/unlock accounting;
- `veniceEmissionsPercentageWhenLocked` behavior;
- emission-rate decrease/increase;
- donation / unsolicited VVV handling;
- rounding and precision;
- upgrade simulation with malicious implementation;
- Safe admin-change monitoring;
- canonical bridge mint/burn authorization;
- LayerZero ULN/DVN configuration if an official route is later identified;
- source/destination supply conservation;
- replay protection;
- withdrawal-liquidity stress;
- `totalLeafLiability <= verified economically realizable NAV`.

## 10. Final decision

**VVV remains SELECTED / P1 research candidate.**

The economic thesis is stronger after ABI verification: the productive position is a real ERC-20 sVVV, the live StakingV2 contract exposes explicit reward/cooldown/DIEM accounting, and the upgrade/admin surface is now identifiable.

However, **do not move VVV to production yet**. The decisive remaining blocker is canonical HyperEVM representation / official cross-chain route. Until Venice or the authenticated bridge layer provides a verifiable HyperEVM VVV/sVVV route, HyperLeaf should not manufacture a wrapped VVV representation.

## Sources

Official / primary:

- Venice FAQ — VVV contract, staking, ownership, emissions, DIEM and cooldowns.
- Venice Crypto RPC documentation — Base VVV staking flow.
- Venice VVV landing page — staking, DIEM and buy/burn model.
- BaseScan sVVV contract page — proxy and implementation history.

ABI / implementation verification:

- StakingV2 verified implementation `0xe37A7920dbc11253ac6d031C29f592f71B348DCA` — live ABI/function/event surface.

Control / risk cross-check:

- 2026 Moonwell VVV listing proposal — staking/admin/upgradability disclosure.
- 2026 Venice token transparency filing — current control/upgradability disclosure.
