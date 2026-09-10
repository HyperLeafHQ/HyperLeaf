# HyperLeaf Asset Evaluation #21 — VVV / Venice AI

Status: **Selected — P1 research candidate; deployment blocked on canonical HyperEVM representation and live ABI verification.**

## Executive conclusion

VVV is materially stronger than a generic governance-token candidate because Venice has a native productive position and an explicit utility/revenue loop:

```text
VVV
 ↓
Venice staking
 ↓
sVVV
 ├─ staking emissions
 └─ lock → DIEM
             ↓
       $1/day Venice API credit

Venice revenue
 ↓
VVV buyback + burn
```

The asset therefore passes the **productive-position** test. Preferred representation is the native staked position (`sVVV` / staking claim), not raw VVV.

## Official-source findings

Venice's current official FAQ states:

- VVV is an ERC-20 on Base at `0xacfE6019Ed1A7Dc6f7B508C02d1b04ec88cC21bf`.
- The VVV token's `owner()` is the staking contract `0x321b7ff75154472B18EDb199033fF4D116F340Ff2`.
- The staking contract owner is a Safe multisig, not a single EOA.
- Emission changes are observable through `emissionRatePerSecond()` and `EmissionRateUpdated` events.
- Current FAQ tokenomics state annual emissions started at 10M VVV, were reduced to 8M, and then to 6M in February 2026.
- Staked VVV earns emissions; sVVV locked to back DIEM earns 80% of standard staking yield while locked.
- Unstaking has a 7-day cooldown.
- DIEM is an ERC-20 minted from locked sVVV and represents $1/day of Venice API credit when staked.
- Unlocking the original sVVV requires burning the same amount of DIEM that was minted; partial burns are allowed.

## Revenue / buyback model

Venice's official materials explicitly connect platform revenue to VVV buyback and burn.

The April 2026 programmatic-burn announcement says new subscriptions trigger automatic VVV purchases and burns, with event amounts based on subscription tier. Venice also states that discretionary revenue-funded burns have operated in parallel.

The July/August 2026 tokenomics update adds a programmatic burn funded by API credit purchases: $5 of every $100 of qualifying credits buys and burns VVV. The DIEM supply target was also increased from 38,000 to 40,000 in staged steps.

Important accounting rule: **buyback/burn is value capture for VVV, but it is not the same thing as a direct holder cash-flow claim.** HyperLeaf must not book burn activity as realized staking yield. The staking emissions and the buyback/burn mechanism are separate economic channels.

## Gate 0

The Base VVV contract is verified by Venice. However, this evaluation does **not** establish a canonical HyperEVM VVV deployment or official HyperEVM staking representation.

Therefore:

- Base canonicality: PASS
- HyperEVM canonical representation: **BLOCKED / must verify**
- Third-party wrapped VVV: insufficient for Gate 0

Production should wait for an official/canonical bridge or representation with authenticated source identity and verified mint/burn authority.

## Preferred HyperLeaf architecture

```text
Base
VVV
 ↓
Venice Staking Contract
 ↓
sVVV / staking position
 ↓
VVV Position Adapter
 ↓
Strategy Vault
 ↓
LayerZero / canonical bridge boundary
 ↓
HyperEVM
 ↓
hVVV
```

The adapter should represent the **staked VVV economic claim**, not merely hold spot VVV.

## Leaf class

**Preferred: Liquid / Rate-bearing**, conditional on verification that the staked position has a transferable canonical representation and that the exchange-rate / reward accounting can be represented without creating unbacked liabilities.

If the source representation is not transferable or requires a non-standard account position, use a dedicated C2/C1 representation instead of forcing it into an ERC-20 LST model.

## Yield accounting

The HyperLeaf accounting must separate:

1. VVV principal;
2. staking emissions;
3. 1% HyperLeaf fee on realized supported staking surplus;
4. DIEM utility value;
5. Venice revenue-funded VVV buybacks/burns;
6. VVV market-price movement;
7. exit liquidity / cooldown value.

Do not treat DIEM market price as VVV NAV.

Do not treat Venice buyback/burn as an immediately claimable reward.

## Critical risks / verification gates

Before production:

- exact live Base staking ABI;
- staking contract implementation and upgradeability;
- Safe ownership and admin powers;
- `emissionRatePerSecond()` and historical emission events;
- sVVV token representation and transferability;
- exact staking/unstaking mechanics;
- 7-day cooldown behavior;
- reward claim semantics;
- DIEM mint-rate and lock relationship;
- DIEM supply target and current supply;
- DIEM burn/unlock invariants;
- buyback executor, burn address and on-chain transaction verification;
- canonical HyperEVM VVV route;
- bridge mint/burn authorization and replay protection;
- source/destination supply reconciliation;
- rate-jump / reward-loss tests;
- donation and rounding tests;
- solvency invariant:

`totalLeafLiability <= verified economically realizable NAV of the staked VVV position`

## Initial product policy

- **Raw VVV:** do not issue hVVV directly from spot VVV.
- **sVVV:** preferred underlying productive position.
- **DIEM:** do not treat as the backing asset for hVVV; it is a separate tokenized compute claim.
- **Buyback/burn:** economic support for VVV, but not direct Leaf yield.
- **HyperEVM:** no deployment until canonical route is independently verified.
- **Cap:** start small and expand only after exit and reward accounting are proven.

## Decision

**VVV = SELECTED / P1 research candidate.**

It is a materially better standalone Leaf candidate than MORPHO because Venice explicitly provides native staking yield plus meaningful protocol utility and revenue-funded buyback/burn mechanics. The remaining blocker is not the economic thesis; it is canonical cross-chain representation and exact source-side position accounting.

## Official references

- Venice FAQ: VVV, staking, contract control, emissions, DIEM and cooldowns.
- Venice: Programmatic VVV Buy & Burns.
- Venice: Tokenomics Update — Credit Burns and Higher DIEM Supply Target.
- Venice: DIEM Technical Breakdown.
