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

### hgSOON (research — wrap gSOON only)

| | |
| --- | --- |
| Canonical backing | transferable gSOON pulled (`0xcC48B55F…e0F7` on **BSC**, ERC-4626, vault=token) |
| Accounting unit | 1 hgSOON = 1 gSOON. Rate vs SOON lives in gSOON (your deposit 1.122 → cooldown 1.434 → live ~1.744) |
| Core invariant | L: `supply ≤ totalLocked gSOON` + gSOON/SOON vault ceiling |
| Proof source | lockbox `totalLocked` + `previewRedeem` / inner supply |
| Mint / redeem | wrap/unwrap **gSOON**. Instant. **Never** `deposit` SOON. **Never** 7d unstake: `cooldownShares(uint256)` 0x9343d9e1 / `cooldownAssets(uint256)` 0xcdac52ed / V2 variants, then `claim(address)` 0x1e83409a after `cooldownDuration` = 604800. Silo is `agingPool` `0x64512C59…` |
| Yield | in the gSOON/SOON rate. Do not pull gSOON as harvest. 90d lock on `0x660102f6` (`lock` 0x1338736f / `withdraw` 0x2e1a7d4d) is extra occupancy — no receipt. Do not enter it |
| Failure | vault upgrade; someone calls cooldown on our lockbox (principal in silo 7d) |
| Auto-pause | ceiling / health |
| Worst-case loss | min(cap, maxPerDay) on gSOON principal. 90d lock APY is not backing |
| Test | L suite. Your path: deposit `0x246a12a4` (2025-05-29, 4998.4994 SOON → 4454.03 gSOON) is the official mint we will not call; lock `0xcaa3905e` / withdraw `0x37d70161` is occupancy we will not enter; cooldownShares `0x5a3c5441` (2025-09-22 21:37 UTC = 09-23 HKT) is the 7d selector. Dust gSOON left on `0x113561…`. Claim after +7d not pinned; selector is still `claim(address)` |



### hAVNT (research → L wrap of stkAVNT, not raw AVNT)

| | |
| --- | --- |
| Canonical backing | transferable stkAVNT from Avantis SM `0xd546040F…d9e9` (Base). **Never** raw AVNT |
| Accounting unit | 1 hAVNT = 1 stkAVNT |
| Core invariant | L: `hAVNT ≤ totalLocked stkAVNT`. Slash (max 20%) is **in** the yield, not stripped |
| Proof source | lockbox `totalLocked` + SM `balanceOf`. `stake(to,amount)` 0xadc9772e mints stkAVNT to `to` |
| Mint / redeem | wrap/unwrap **stkAVNT**. Instant. **Never** `cooldown()` / unstake window. Live `COOLDOWN_SECONDS` = 64800 (18h); do not use the old 5d docs figure as a call we make |
| Yield | extra AVNT emissions → HYPE. Fee discounts / XP stay on the lockbox (occupancy) |
| Failure | SM slash, AVNT blacklist (`isBlackListed` on the token), emission stop |
| Auto-pause | health after a slash event; ceiling on AVNT/stkAVNT supply |
| Worst-case loss | 20% slash of locked stack + daily cap on residual |
| Test | L suite + “we never call cooldown”. Your pin: Base `0x7aaf51e8` (2025-10-02 17:59 UTC / 10-03 01:59 HKT) `stake(self, 6.1e18)` — 6.1 AVNT in, 6.1 stkAVNT minted to `0x113561…`. 400 AVNT stake not in ±3d of this tx |



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

### hORDER (research — stake + VALOR redeem request pinned, esORDER claim not)

| | |
| --- | --- |
| Canonical backing | ORDER staked on Orderly omnichain ledger, **keyed by lockbox EVM address**. Not OP `balanceOf`. Not VALOR |
| Accounting unit | C1 ticker. VALOR is a non-transferable metric, not a token |
| Core invariant | HyperEVM hORDER ≤ ORDER the lockbox staked on the ledger. Same EVM address on ETH/OP/Base/… sees one position |
| Proof source | `stakeOrder` on proxy `0xC8A8Ce0A…` (CREATE2, all EVMs). ORDER OFT burns on the source chain, LZ eid **30213** (Orderly). **Not** `ORDER.balanceOf(proxy)` |
| Mint / redeem | C1, market-only. Lockbox calls `stakeOrder(uint256)` 0x413aaa60. Unstake 7d then `sendUserRequest(amount, payloadType)` 0xcec09c0d (2 request, 3 cancel, 4 withdraw). **Receive chain is not OP.** ORDER OFT (`0x4E200fE2`, same addr) can land on Arb or Base — deploy the lockbox on the chain we want to receive. Ledger keys by **that** address. CREATE2 same address on Arb+Base if we want both. ETH claim is ERC-20, not OFT. VALOR type 17 also pins claim chain at submit. **Never** wrap VALOR |
| Yield | VALOR on the staking address. Legacy: `sendUserRequest(valor, 9)` then `sendUserRequest(usdcAmt, 10)` — USDC lands on the dest chain. Your pin: Base `0x8bb2dcc0` type 10 + compose `0x93ec1d61` **1.156239 USDC** to `…16BA` (2025-09-28 02:14 HKT). Request was `0xd64c6995` type 9 (64.00 VALOR, 09-21). New: type **17** (Arb `0x7a9676a6` 0.001, 2026-09-07) → esORDER after wait. Do **not** vest esORDER. Harvest-to-HYPE for the old pool is USDC in the lockbox |
| Failure | LZ message not credited; stake from user EOA so VALOR is not on the lockbox; type 17 / unstake claim from a chain with no lockbox so OFT lands on an empty address; 7d unstake from lockbox |
| Auto-pause | health. Do not mint if ledger stake of lockbox is below hORDER |
| Worst-case loss | all TVL (C1, no protocol peg-out). LZ / ledger failure |
| Test | `test/lz/LeafOmnichainCreate2.t.sol`. OP stake `0x09494257`/`0x76ea3caf` (1196). Base unstake type 2 `0x447d97ac` then withdraw type 4 `0x5aa28832` — **1196 ORDER OFT arrived on Base** `0xdd65ff33`. Interest: 1.156 USDC Base `0x93ec1d61`. New VALOR type 17 Arb `0x7a9676a6`. CREATE2 same lockbox on Arb/Base. New-path esORDER claim still +7d |


### PTSMAX

Accounting unit is **sRIVER_V2 tokenId**, not `balanceOf(Pts)`. Do not ship on the ERC-20 adapter. Merkle weekly Pts is address-keyed, not NFT-keyed. Blocked on NFT lockbox + lockbox appearing in a weekly tree.

### hSKY / hAAVE

Parked. A row that says `hSKY ≤ LSSKY balance` is **rejected**. Realizable value is SKY principal + rewards − USDS debt − penalties. stkAAVE is not 1:1 AAVE.

## Global outflow

Inner leaving a lockbox ≤ **that** lockbox `maxPerDay` on redeem. Dest `maxPerDay` only bounds new hTokens. Set them equal.

## Claim calls

`pokeClaim` requires `setClaimCall(target, selector)`.
