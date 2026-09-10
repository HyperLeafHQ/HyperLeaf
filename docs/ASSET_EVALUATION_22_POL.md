# HyperLeaf Asset Evaluation #22 — POL / Polygon

Status: **Selected — P1 research candidate; sPOL is the canonical LST priority. Production blocked on final custody/cross-chain and source-side verification.**

## 1. Executive conclusion

Polygon now has a clear canonical LST for POL: **sPOL**, issued by Polygon Labs. Polygon's own documentation defines sPOL as a liquid staking token representing a staked POL position, with staking rewards reflected through exchange-rate appreciation. The official launch describes sPOL as Polygon's native LST and says it was audited by ChainSecurity and Certora. citeturn0search0turn0search1turn2search8

Preferred representation:

```text
POL
 ↓
Polygon Labs sPOL
 ↓
verified sPOL NAV / exchange rate
 ↓
POL Position Adapter
 ↓
Strategy Vault / authenticated custody
 ↓
HyperEVM hPOL
```

**Do not build a new native POL staking receipt unless sPOL is unavailable for a specific deployment constraint.** This follows HyperLeaf's canonical-LST priority rule.

## 2. Why sPOL wins Gate 0 on the source side

- Polygon explicitly calls sPOL its native liquid staking token.
- sPOL is a transferable ERC-20 representing a share of the staked POL pool.
- Rewards accrue through the sPOL/POL exchange rate rather than rebasing.
- The protocol compounds rewards and manages validator delegation.
- Official terms state that sPOL can be redeemed for underlying POL plus accrued rewards, less applicable fees/slashing losses, subject to the unbonding process.
- Polygon launched sPOL with treasury liquidity support: 10M POL-equivalent initially and a stated target of 100M for liquidity support.

Current Polygon validator dashboard shows approximately **3.58B POL staked**, 105 active validators and 28,452 delegators, demonstrating a large underlying staking base. citeturn0search2

## 3. Canonical sPOL contracts

Polygon's official sPOL repository and security scope publish these mainnet contracts:

### Ethereum

- sPOL: `0x3B790d651e950497c7723D47B24E6f61534f7969`
- sPOLController: `0xEaadA411F2600570796c341552b9869DA708a28B`
- sPOLMessenger: `0x0356e303B375D5a11D9Eb7d57DBF544FeE6972C9`
- AccessManager: `0x2c91c02793a50f6D55168a88183da687F572d350`
- PolBridger: `0x71663898Df7470e3b64d52663Ff975895E9b06E8`

### Polygon PoS

- sPOLChild: `0xd1CD49A08AeF3Af93457aEc17C786C2b7F48eCd7`
- AccessManager: `0x2c91c02793a50f6D55168a88183da687F572d350`
- PolBridger: `0x71663898Df7470e3b64d52663Ff975895E9b06E8`

The Polygon repository describes the architecture as L1 sPOL + controller + messenger, with an L2 sPOLChild using Polygon state-sync and a cached exchange rate. citeturn1search1turn1search2

## 4. Economic model

sPOL is a non-rebasing, value-accruing LST:

```text
POL deposited
  ↓
managed validator staking
  ↓
staking rewards + eligible priority-fee economics
  ↓
rewards compounded
  ↓
sPOL exchange rate increases
```

Polygon's support documentation explicitly states that base staking rewards are reflected in the exchange rate. The live official interface currently advertises up to roughly 3.85% APY, but HyperLeaf must treat APY as informational and derive NAV from on-chain state rather than hard-code it. citeturn2search8turn0search13

## 5. HyperLeaf representation

Recommended accounting:

```text
Source chain custody
    POL → sPOL
          |
          | authenticated state / custody message
          v
HyperEVM Strategy Vault
          |
          v
       hPOL
```

Leaf class: **Liquid / Rate-bearing**, conditionally.

The condition is that the custody boundary must expose a fresh, authenticated sPOL balance and exchange-rate/NAV state and that exit liquidity is sufficient for the configured HyperLeaf cap. Transferability of sPOL itself does not automatically mean HyperLeaf can provide instant cross-chain redemption.

Core invariant:

`totalLeafLiability <= verified economically realizable sPOL NAV`

## 6. Important cross-chain finding

**No official Polygon Labs sPOL deployment on HyperEVM was identified in the current official sPOL deployment documentation.** The official deployment matrix lists Ethereum and Polygon PoS, not HyperEVM. Therefore a random HyperEVM `sPOL`/`POL` token must not be accepted as canonical backing. citeturn1search1turn1search2

This is not a reason to reject the asset. HyperLeaf can, in principle, issue hPOL against its own authenticated source-side custody of canonical sPOL, provided the bridge/message/custody layer proves:

- source-chain contract identity;
- exact sPOL balance;
- current exchange-rate/NAV state;
- replay protection;
- message freshness / staleness bounds;
- source/destination accounting conservation;
- controlled withdrawal and emergency recovery.

A third-party wrapped POL/sPOL token on HyperEVM is **not** sufficient.

## 7. Security / admin surface

The official repository describes `sPOLController`, `sPOL`, and `sPOLMessenger` as upgradeable and controlled through AccessManager roles. The repository also documents validator-management, exchange-rate update and pausing roles. citeturn1search3

HyperLeaf must therefore verify before production:

1. proxy implementation addresses;
2. AccessManager role members and thresholds;
3. exchange-rate updater authorization;
4. pause authority;
5. validator-set management;
6. unbonding queue accounting;
7. controller ↔ sPOL mint/burn authorization;
8. L2 cached-rate staleness and update path;
9. PolBridger configuration;
10. upgrade events and timelock/guardian policy if present.

## 8. Production gates

### Gate A — source asset

- [x] POL is productive through Polygon PoS staking.
- [x] Canonical Polygon-native LST exists: sPOL.
- [x] sPOL is transferable ERC-20.
- [x] Reward accrual is exchange-rate based.
- [x] Official contract addresses published.
- [x] ChainSecurity + Certora audits publicly referenced.

### Gate B — HyperLeaf custody

- [ ] Source-side sPOL custody contract.
- [ ] Authenticated source-state messenger.
- [ ] Freshness/staleness bound.
- [ ] Source/destination supply conservation.
- [ ] Emergency pause/recovery.
- [ ] Verified exit-liquidity floor.

### Gate C — accounting

- [ ] `totalLeafLiability <= verified sPOL NAV` invariant.
- [ ] Exchange-rate decrease/slashing handling.
- [ ] Unsolicited sPOL/POL donation handling.
- [ ] Rounding/decimal tests.
- [ ] Rate-jump breaker.
- [ ] Cross-chain replay tests.

## 9. Code direction

Initial code should be a **read-only/source-side sPOL adapter**, not a production bridge. It should:

- bind immutable canonical sPOL + controller addresses;
- expose sPOL balance and verified exchange-rate/NAV inputs;
- reject arbitrary token/router substitution;
- provide a conservative NAV view for the Strategy Vault;
- leave cross-chain authentication as a separate boundary.

See:

- `src/interfaces/ISPOL.sol`
- `src/adapters/SPOLAdapter.sol`

These files are deliberately not a bridge and do not mint hPOL. They provide the accounting boundary required before the bridge/custody layer is finalized.

## 10. Final decision

**POL / sPOL = SELECTED, P1.**

This is a materially stronger candidate than raw POL because Polygon now has an official, native, exchange-rate-bearing LST. The correct HyperLeaf direction is **sPOL-first**, not native POL self-staking and not a spot POL wrapper.

The remaining blocker is not the economic asset thesis. It is the **authenticated source-side custody + HyperEVM accounting boundary**. Do not promote a third-party HyperEVM POL/sPOL token to canonical backing.

## Sources

- Polygon Labs — sPOL launch and native LST description.
- Polygon Labs — sPOL Terms of Use and Risk Disclosures.
- Polygon support — sPOL acquisition, rewards and redemption.
- Polygon official `0xPolygon/sPOL-contracts` repository and deployment data.
- Polygon security repository — audited sPOL deployment scope.
- Polygon validator dashboard — current staking/validator state.
