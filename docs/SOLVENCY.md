# Asset solvency (onboarding interface)

`catalog.json` is config, not a proof. L / C1 / C2 is **how you exit**. ERC-20 / 4626 / NFT / merkle is **how you count**. This file is **why the hAsset is allowed to exist**.

A new ticker does **not** get Solidity until its row is filled and a third party can check it. AI may write the adapter. AI may not invent the solvency story.

```
New asset
 → fill this row
 → name the invariant
 → name origin and failure
 → set pause + max loss
 → then code
 → tests must preserve the invariant
```

Peg caps and `balanceOf` cash checks limit blast radius. They do not make a forged inner token real. See [`TRUST.md`](TRUST.md).

## Required fields

| Field | Means |
| ----- | ----- |
| Canonical backing | What we actually hold |
| Accounting unit | 1 hToken = ? |
| **Core invariant** | Inequality that must hold after mint, transfer, burn, donation, reward, upgrade |
| **Proof source** | Which contract state proves it |
| Mint / redeem authority | Who can create or destroy the claim |
| Yield | What extra income is, and what it is not |
| Failure trigger | When we stop believing the inner |
| Auto-pause | What on-chain action that maps to |
| Worst-case loss | Bound, not a hope |
| Test | File that would fail if the invariant broke |

Backed ≠ redeemable. A blacklist can freeze exit while backing is still there.

## Listings

### hNEST (live, capped)

| | |
| --- | --- |
| Canonical backing | NEST in NestVault / HEV |
| Accounting unit | hNEST shares |
| Core invariant | hNEST supply ≤ economically realizable NEST (idle + HEV − pending exits − fees) |
| Proof source | NestVault accounting (main) |
| Yield | extra NEST (compound off) + weekly HYPE |
| Failure | HEV mis-account |
| Auto-pause | guardian |
| Worst-case loss | deposit cap |
| Test | `test/NestVault.t.sol` |

### hxSQUID (next L)

| | |
| --- | --- |
| Canonical backing | xSQUID **pulled** into the lockbox (`totalLocked`), not donations |
| Accounting unit | 1 hxSQUID = 1 locked xSQUID |
| Core invariant | `oft.totalSupply() ≤ adapter.totalLocked() ≤ depositCap` and `inner.totalSupply() ≤ ceiling` |
| Proof source | `totalLocked` + `innerSupplyCeiling` + cash on redeem |
| Yield | QUID → HYPE. Never pull xSQUID as yield |
| Failure | Squid print, `claimRewards` selector drift |
| Auto-pause | `reportInnerSupply` → Degraded |
| Worst-case loss | min(depositCap, source maxPerDay) |
| Test | `test/lz/LeafSolvency.t.sol` |

### hcbETH (next L)

Same L invariant. Ceiling = Coinbase cbETH supply headroom. Yield stays in cbETH rate; do not pull inner as yield.

### hKAITO (blocked on omnichain holder)

Same L invariant on **sKAITO**, not KAITO. Official 7d unstake is never called. Blacklist can make redeem fail while still backed. Eco ERC-20s are yield, not backing.

### BLUAI4Y / hVIRTUALMAX (C1)

Invariant: HyperEVM supply ≤ inbound `totalLocked` of the farm/lock **we opened**. No protocol peg-out until `shareExit`. Accounting unit is the ticker, not a random ERC-20 balance. Max protocol loss on a fake inner is “we stop minting”; we do not pay BTC-style redeem.

### hsETHFI (research → L, Ethereum)

| | |
| --- | --- |
| Canonical backing | sETHFI **pulled** (BoringGovernance share `0x86B5780b…c0161`), not ETHFI |
| Accounting unit | 1 hsETHFI = 1 sETHFI |
| Core invariant | same L: `supply ≤ totalLocked ≤ cap` + sETHFI supply ceiling |
| Proof source | lockbox `totalLocked` + ether.fi vault share supply |
| Mint / redeem | `send` / burn → sETHFI. **Never** `DelayedWithdraw` (~10d to ETHFI) or the teller `deposit` |
| Yield | sETHFI NAV in the share (do not pull inner). Extra: merkle ERC-20s — ETHFI/EIGEN seasons empty; live is **KING** (`0x8F08B704`) via `0x6Db24` `claim` 0x1d7d4ebc. Leaf must be the lockbox |
| Failure | vault upgrade; merkle paid to EOA; KING campaign replaced again |
| Auto-pause | ceiling / health |
| Worst-case loss | min(cap, maxPerDay) on principal. KING/ETHFI/EIGEN are yield, not backing |
| Test | L suite. Deposit 0x24a993c9. Do not treat empty ETHFI/EIGEN distributors as current yield |

### hgSOON (research — row incomplete)

gSOON is a transferable LST (rate vs SOON, 7d unstake we never call). Arkham: ~199M SOON in “GSOON” vs ~187M on Solana — Ethereum/BSC first. **Canonical address not pinned.** `0xcC4…` on Arkham is truncated. Do not write an adapter until a gSOON transfer or stake tx gives the full token + vault.

### hAVNT (research → L wrap of stkAVNT, not raw AVNT)

| | |
| --- | --- |
| Canonical backing | stkAVNT from Avantis SM `0xd546040F08E6b3A4F1D21683b9bd9935d73bd9e9` (Base) |
| Accounting unit | 1 hAVNT = 1 stkAVNT |
| Core invariant | L: `hAVNT ≤ totalLocked stkAVNT`. Slash (max 20%) is **in** the yield, not stripped |
| Proof source | `stake(to,amount)` mints stkAVNT; cooldown 5d + unstake window 3d **never called** |
| Yield | extra AVNT emissions → HYPE. Fee discounts / XP stay on the lockbox (occupancy) |
| Failure | SM slash, AVNT blacklist (`isBlackListed` on the token), emission stop |
| Auto-pause | health after a slash event; ceiling on AVNT/stkAVNT supply |
| Worst-case loss | 20% slash of locked stack + daily cap on residual |
| Test | L suite + “we never call cooldown”. Need your stake tx to confirm transferable stkAVNT |

Public sample (not yours): Base `0x9fbb56ba99…` `stake(address,uint256)` 0xadc9772e.

### hB3 (research — stake path live, yield incomplete)

| | |
| --- | --- |
| Canonical backing | B3 staked via `stakeFor(lockbox, amt)` on `0x18541`. **Principal then sits in EOA `0x8D06` (no code)** |
| Accounting unit | C1 ticker. No receipt token |
| Core invariant | HyperEVM hB3 ≤ inbound B3 we staked. We cannot prove EOA still holds it |
| Proof source | `Staked` event on 0x18541. **Not** `balanceOf(stake)` — tokens leave |
| Yield | WIN — **not in the stake tx**. Need a claim tx |
| Failure | EOA moves B3; WIN paid to EOA not lockbox; games/spins on the stake account |
| Auto-pause | health. Do not mint if team wallet drained |
| Worst-case loss | all TVL (custodial). C1: no protocol peg-out |
| Test | do not ship until WIN claim is pinned. A row that says `hB3 ≤ B3.balanceOf(0x18541)` is **rejected** |

### hORDER (research — incomplete)

### PTSMAX

Accounting unit is **sRIVER_V2 tokenId**, not `balanceOf(Pts)`. Do not ship on the ERC-20 adapter. Merkle weekly Pts is address-keyed, not NFT-keyed. Blocked on NFT lockbox + lockbox appearing in a weekly tree.

### hSKY / hAAVE

Parked. A row that says `hSKY ≤ LSSKY balance` is **rejected**. Realizable value is SKY principal + rewards − USDS debt − penalties. stkAAVE is not 1:1 AAVE.

## Global outflow

Inner leaving a lockbox ≤ **that** lockbox `maxPerDay` on redeem. Dest `maxPerDay` only bounds new hTokens. Set them equal.

## Claim calls

`pokeClaim` requires `setClaimCall(target, selector)`.
