# HyperLeaf Asset Evaluation #21 — VVV / Venice AI

Status: **Selected — P1 research candidate; deployment blocked on canonical HyperEVM representation and live ABI verification.**

VVV passes the productive-position test because Venice provides native VVV staking, staking emissions, DIEM utility backed by locked sVVV, and a revenue-funded VVV buyback/burn mechanism.

## Official-source findings

- VVV is an ERC-20 on Base at `0xacfE6019Ed1A7Dc6f7B508C02d1b04ec88cC21bf`.
- VVV `owner()` is the staking contract `0x321b7ff75154472B18EDb199033fF4D116F340Ff2`.
- The staking contract owner is a Safe multisig.
- Venice's current FAQ states annual emissions started at 10M VVV, were reduced to 8M and then to 6M in February 2026.
- Staked VVV earns emissions; sVVV locked to back DIEM earns 80% of standard staking yield while locked.
- Unstaking has a 7-day cooldown.
- DIEM is an ERC-20 minted from locked sVVV and represents $1/day of Venice API credit when staked.
- Unlocking the original sVVV requires burning the same amount of DIEM that was minted.

## Revenue / buyback model

Venice's official materials explicitly connect platform revenue to VVV buyback and burn. The April 2026 programmatic-burn announcement describes subscription-triggered automatic buys/burns. The July/August 2026 tokenomics update adds a programmatic burn funded by API credit purchases: $5 of every $100 of qualifying credits buys and burns VVV.

**Accounting rule:** buyback/burn is value capture for VVV, not a direct holder cash-flow claim. HyperLeaf must not book burn activity as realized staking yield.

## Gate 0

- Base canonicality: **PASS**
- Canonical HyperEVM VVV representation: **BLOCKED / must verify**
- Third-party wrapped VVV: **insufficient**

Production requires an authenticated canonical bridge/representation with verified mint/burn authority and source/destination supply conservation.

## Preferred architecture

```text
Base VVV
  ↓
Venice Staking
  ↓
sVVV / staking claim
  ↓
VVV Position Adapter
  ↓
Strategy Vault
  ↓
canonical bridge boundary
  ↓
HyperEVM hVVV
```

Do not wrap raw VVV as hVVV. The underlying claim should be the productive staking position.

## Leaf class

Preferred: **Liquid / Rate-bearing**, conditional on verification of a transferable canonical staking representation and deterministic reward/accounting semantics. If the source representation is not transferable, use a dedicated C1/C2 design rather than forcing an ERC-20 LST abstraction.

## Yield accounting

Separate VVV principal, staking emissions, the 1% HyperLeaf fee on realized supported staking surplus, DIEM utility value, Venice revenue-funded buybacks/burns, VVV market-price movement, and exit liquidity/cooldown value.

Do not treat DIEM market price as VVV NAV. Do not treat buyback/burn as an immediately claimable reward.

## Critical verification gates

- exact live Base staking ABI;
- staking implementation / upgradeability;
- Safe admin powers;
- `emissionRatePerSecond()` and historical emission events;
- sVVV representation and transferability;
- 7-day cooldown mechanics;
- reward claim semantics;
- DIEM mint-rate / lock relationship;
- DIEM burn/unlock invariant;
- buyback executor and burn destination;
- canonical HyperEVM route;
- bridge mint/burn authorization and replay protection;
- source/destination supply reconciliation;
- rate-jump, loss, donation and rounding tests;
- `totalLeafLiability <= verified economically realizable NAV`.

## Product policy

- Raw VVV: **no direct hVVV**.
- sVVV: preferred productive position.
- DIEM: separate compute asset, not hVVV backing.
- Buyback/burn: economic support, not direct Leaf yield.
- HyperEVM: no deployment until canonical route is independently verified.
- Start with a small cap after exit and reward accounting are proven.

## Decision

**VVV = SELECTED / P1 research candidate.**

VVV is materially stronger as a standalone Leaf candidate than MORPHO because the productive position is native, staking is explicit, utility is real, and Venice directly links platform revenue to VVV buyback/burn. The remaining blocker is canonical HyperEVM representation and exact source-side position accounting.

## Official references

- Venice FAQ — VVV / staking / contract control / emissions / DIEM / cooldowns
- Venice — Programmatic VVV Buy & Burns
- Venice — Tokenomics Update: Credit Burns and Higher DIEM Supply Target
- Venice — DIEM Technical Breakdown
