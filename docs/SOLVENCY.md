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
| Failure | Squid print; `rewardsSelector` drift to `redeem(address,uint256)` `0x1e9a6950` (denied in `LeafYieldFee`) |
| Auto-pause | `reportInnerSupply` → Degraded |
| Worst-case loss | min(depositCap, source maxPerDay) |
| Test | `test/lz/LeafSolvency.t.sol` |

### hJitoSOL (Solana L — first non-EVM, rate skim)

| | |
| --- | --- |
| Canonical backing | JitoSOL **pulled** into a Solana PDA (`J1toso1u…GCPn`). Never SOL. Never the stake pool |
| Accounting unit | hJitoSOL **shares** (18 dp). `shares = atoms * 1e9`. Remaining JitoSOL per share moves only by the 1% skim |
| Core invariant | dest `totalSupply` ≤ Solana `total_shares`. PDA JitoSOL ≥ `lastAccounted`. `pool_mint` on the rate account is the JitoSOL mint |
| Rate source | Jito stake pool `Jito4APyf642…Awbb`: `total_lamports / pool_token_supply`. Same class as cbETH `exchangeRate` |
| Rate trust | SPL stake-pool program + Jito manager. Anomalous jump/drop/upgrade |
| Rate anomaly | jump → 1% of surplus, floor, cannot sell donations. drop → watermark down, pull 0 |
| Maximum harvest | **1% of** `(lastAccounted * (rate - lastRate)) / rate`. 99% stays in the PDA. Floor: surplus < 100 atoms → fee 0, watermark still moves, dust stays with holders. Low TVL can mean protocol take = 0 |
| Proof source | PDA token balance + pool account + `LeafJitoRate` |
| Mint / redeem | lock JitoSOL / unlock remaining JitoSOL. **Never** `depositSol` / `withdrawSol` / `depositStake` |
| Yield | staking + MEV/TOV **inside the rate**, left in remaining JitoSOL. Protocol skims 1% JitoSOL → harvest ATA → WHYPE. Holders have **no** WHYPE claim |
| NCN / Switchboard | **Not backing, not this listing.** SWTCH and TipRouter restake rewards require depositing JitoSOL into a Jito Vault (VRT, slashable). Lockbox never CPI Vault `Vau1t6sL…` or Restaking `RestkWeA…`. Idle PDA does not earn them. Token-push airdrops to the PDA ATA: `harvest_other`, not JitoSOL |
| Donation | extra JitoSOL into the PDA is extra backing, not yield |
| Failure | Solana program upgrade; pool_mint mismatch; EVM `WirePeers(address)` instead of 32-byte PDA; confirmations < 32 |
| Auto-pause | guardian halt on dest OFT; source pause |
| Worst-case loss | dest `supplyCap` / `maxPerDay`. Yield path loss is converter on the 1% skim only |
| Test | `test/lz/LeafJitoRate.t.sol` + `solana/leaf-jito-rate` `cargo test`. Spec: `docs/SOLANA_JITOSOL.md` |

Not batch 0–4. `BATCH=5`. Dest `DeployOFT`. Source is not `DeployAdapter`.

### hcbETH (rate L)

| | |
| --- | --- |
| Canonical backing | cbETH **pulled** into the lockbox. After skim, remaining cbETH (includes 99% of rate surplus) |
| Accounting unit | hcbETH **shares**. Quantity of cbETH per share moves only by the 1% protocol skim |
| Core invariant | `oft.totalSupply() ≤ adapter.totalLocked()` (shares). Remaining inner ≥ lastAccounted. `lastAccounted + accruedRateYield ≤ inner.balanceOf(lockbox)` |
| Rate source | Coinbase cbETH `exchangeRate()`. This is a solvency oracle, not a price feed we control |
| Rate trust | upstream contract implementation / upgrade. Anomalous jump, drop, stale return, or malicious upgrade |
| Rate anomaly | jump → surplus floors and caps at lastAccounted (cannot sell donations). drop → watermark down, pull 0. Never harvest a donated balance |
| Maximum harvest | **1% of** `(lastAccounted * (rate - lastRate)) / rate` (floor). 99% stays in the box. Surplus < 100 inner atoms → fee 0; watermark still moves; dust stays with holders. Low TVL can mean protocol take = 0. Wrap/redeem settle this 1% before minting or paying out (flush if convert on; book if halted) |
| Proof source | `lastAccounted` + `exchangeRate()` + cash on redeem. `retainRateYield = true` |
| Mint / redeem | wrap/unwrap cbETH. Later deposits mint at remaining-inner NAV. Last exit pays remaining inner. **Never** Coinbase unwrap |
| Yield | ETH PoS inside `exchangeRate()`, **left in the receipt** (Lido/wstETH). Protocol skims 1% of surplus to converter → HYPE. Holders have **no** WHYPE claim. LP/lend keep the 99% |
| Donation | extra `transfer` into the lockbox is **not** yield. It is extra backing. It must not mint HYPE or pay the 1% |
| Failure | Coinbase rate lie / upgrade; converter swap on the 1% only; inner print (`innerSupplyCeiling`) |
| Auto-pause | `reportInnerSupply` → Degraded. Guardian close |
| Worst-case loss | min(depositCap, maxPerDay) on principal. Yield path loss is converter execution on the 1% skim |
| Test | `test/lz/LeafRateYield.t.sol` — 1% skim, 99% retained, slash, NAV mint, donation invariance, floor rounding, rate fuzz, sell-all still works if retain is off |

Do **not** enable `rateKind` on Morpho shares unless that listing's row says pull rate surplus. **hgSOON and hsWBERA opt in:** `ConvertToAssets` + `retainRateYield` (same 1% skim as hcbETH).

Converter `minOut` is enforced on `LeafYieldConverter.execute` (balance delta) and `notify(amount, minAmount)`. It is **not** a lockbox invariant — wrap/redeem never talk to the converter. A dead hop: `halt` + `returnToLockbox`. Next hop can be a different allowlisted bridge (deBridge / Mayan / Relay).



### hKAITO (blocked on omnichain holder)

Same L invariant on **sKAITO**, not KAITO. Official 7d unstake is never called. Blacklist can make redeem fail while still backed. Eco ERC-20s are yield, not backing.

### BLUAI4Y / hVIRTUALMAX (C1)

Invariant: HyperEVM supply ≤ inbound `totalLocked` of the farm/lock **we opened**. No protocol peg-out until `shareExit`. Accounting unit is the ticker, not a random ERC-20 balance. Max protocol loss on a fake inner is “we stop minting”; we do not pay BTC-style redeem.

### hsETHFI (next testnet — wrap sETHFI, yield-in-share L, Ethereum)

| | |
| --- | --- |
| Canonical backing | sETHFI **pulled** (BoringGovernance share `0x86B5780b606940Eb59A062aA85a07959518c0161` on **Ethereum**). Same address exists on Base/OP/Arb/Scroll — **do not open a second source**. ~90M sETHFI / ~80–96% of ETHFI backing sit on ETH. |
| Accounting unit | 1 hsETHFI = 1 sETHFI |
| Core invariant | same L: `supply ≤ totalLocked ≤ cap` + sETHFI supply ceiling |
| Proof source | lockbox `totalLocked` + ether.fi vault share supply |
| Mint / redeem | `send` / burn → sETHFI. **Never** `DelayedWithdraw` (`0x1509b1fd…`, ~10d to ETHFI) or the teller `deposit` `0x0efe6a8b`. User who wants ETHFI: unwrap hsETHFI, then official queue. |
| Yield | sETHFI NAV stays in the share (no `retainRateYield` — sETHFI is not ERC-4626 / no `convertToAssets`). Extra merkle ERC-20s: ETHFI/EIGEN seasons empty; live is **KING** (`0x8F08B704`) via `0x6Db24` `claim` `0x1d7d4ebc`. Merkle is KAITO-class: lockbox must be the leaf. **This round does not set a rewardsSelector** — poke would send `(this, max)` which is the wrong ABI. Do not block L. |
| Failure | vault upgrade; merkle paid to EOA; KING campaign replaced; wrapping Base/OP copies into the same dest OFT |
| Auto-pause | ceiling / health |
| Worst-case loss | min(cap, maxPerDay) on principal. KING/ETHFI/EIGEN are yield, not backing |
| Test | `testRewardsSelectorRejectsSethfiDelayedWithdrawAndMerkle`. Deposit `0x24a993c9`. `BATCH=3` `ASSET=hsethfi`. Do not treat empty ETHFI/EIGEN distributors as current yield |

### hgSOON (next testnet — wrap gSOON, cbETH-class 1% skim)

| | |
| --- | --- |
| Canonical backing | transferable gSOON pulled (`0xcC48B55F6c16d4248EC6D78c11Ba19c1183Fe0F7` on **BSC**) |
| Accounting unit | hgSOON **shares**. Remaining gSOON per share moves only by the 1% protocol skim |
| Core invariant | `oft.totalSupply() ≤ adapter.totalLocked()` (shares). Remaining inner ≥ lastAccounted |
| Rate source | gSOON `convertToAssets(1e18)` (`RateKind.ConvertToAssets`). Not `exchangeRate()` |
| Maximum harvest | **1% of** `(lastAccounted * (rate - lastRate)) / rate` (floor). Surplus < 100 atoms → fee 0. Wrap/redeem settle this 1% before mint/payout |
| Mint / redeem | wrap/unwrap **gSOON**. Instant. After skim, remaining gSOON is not 1:1. **Never** `deposit` SOON `0x6e553f65`. **Never** `cooldownShares` 0x9343d9e1 / `cooldownAssets` 0xcdac52ed / `claim` 0x1e83409a |
| Yield | SOON staking already in the 4626 rate. Protocol skims 1% of surplus to converter → HYPE. Holders have **no** WHYPE claim. LP/lend keep the 99% |
| Donation | extra gSOON transfer is backing, not yield |
| 90d lock | occupancy on `0x660102f6` (`lock(uint256,uint256)` 0x1338736f). Do not enter |
| Pins (16ba) | deposit1 `0x246a12a4` @ 1.1222. deposit2 `0xc6559838` @ 1.2237. cooldownShares `0x5a3c5441` @ 1.4345. Live ~1.7447 |
| Failure | vault upgrade; cooldown on the lockbox |
| Auto-pause | ceiling / health |
| Worst-case loss | min(cap, maxPerDay) on principal. Converter execution on the 1% skim |
| Test | `testGsoonConvertToAssetsSameMathAsCbeth`, `testRewardsSelectorRejectsGsoonCooldownAndLock` |
| Testnet | BSC testnet 97 `MockConvertERC20`. `setRateKind(ConvertToAssets)` + `setRetainRateYield(true)`. No `setRewardsSelector` |



### hAVNT (L wrap of stkAVNT, not raw AVNT)

| | |
| --- | --- |
| Canonical backing | transferable stkAVNT from Avantis SM `0xd546040F…d9e9` (Base). **Never** raw AVNT |
| Accounting unit | 1 hAVNT = 1 stkAVNT |
| Core invariant | L: `hAVNT ≤ totalLocked stkAVNT`. Slash (max 20%) is **in** the receipt |
| Proof source | lockbox `totalLocked` + SM `balanceOf` |
| Mint / redeem | wrap/unwrap **stkAVNT**. Instant. **Never** `cooldown()` `0x787a08a6` or `claimRewardsAndRedeem` `0xeab52318` |
| Yield | extra AVNT → converter → WHYPE. `pokeRewards` = `claimRewards(address,uint256)` **selector** `0x9a99b4f0`. Claim **tx** `0x26f4ca90` (51.68 AVNT, stkAVNT untouched). Combined-redeem **tx** `0x24398d72` uses selector `0xeab52318` — already forbidden. Do not treat a tx hash as a selector |
| Failure | SM slash, AVNT `isBlackListed`, emission stop |
| Auto-pause | health after slash; ceiling on stkAVNT supply |
| Worst-case loss | 20% slash of locked stack + daily cap |
| Test | `testRewardsSelectorRejectsAvntRedeemCombo`. Stake pin `0x7aaf51e8` |

### hveUP (watch — not L, no adapter)

up. is Velodrome-line ve(3,3) on **Robinhood Chain 4663**. Liquid **UP** `0x57C0E45c…B4F1` is the emission token. Yield sits on **veUP** escrow NFT `0x5d321dE3…B7B6` (fees + votes). Wrapping UP would be wrapping spot. Wrapping veUP needs the same NFT lockbox as hveAERO. LZ exists (eid **30416**, EndpointV2 `0x6F475642…`). Do not write LeafOFTAdapter for this ticker.

### Morpho vault shares (family — L, wrap the 4626 token)

Morpho **Vault** (MetaMorpho / Vault V2) deposits mint a transferable ERC-4626 share. That share is the inner. Morpho **Blue market** supply is an address-keyed position — not an ERC-20. Do not wrap Blue. Do not wrap USDC/USDG. Do not wrap borrow.

One vault = one listing. Backing does not cross curators or loan assets.

| | |
| --- | --- |
| Canonical backing | vault share pulled on the source chain |
| Accounting unit | 1 hToken = 1 share. Loan-asset NAV in `convertToAssets` |
| Core invariant | L: `supply ≤ totalLocked shares` + share `totalSupply` ceiling |
| Mint / redeem | wrap/unwrap **shares**. Instant. **Never** `deposit`/`mint`/`withdraw`/`redeem` on the vault (even if Morpho redeem is “instant”) |
| Yield | in the share rate. Do not pull shares as harvest. Extra reward tokens (MORPHO etc.) may `pullYield` only if not the inner |
| Failure | curator reallocation, market illiquidity (user sells hToken), USDC/USDG depeg, Morpho/adapter bug |
| Auto-pause | share/loan-asset depeg vs oracle; inner supply ceiling |
| Test | L suite + forbidden 4626 selectors. Per-vault `asset()` logged before adapter-ready |

**hsteakUSDC** (Base): inner `0xBEEF010f…8183`, asset USDC. First Base Morpho candidate (same chain as hxSQUID).

**hsteakUSDG** (Robinhood): inner `0xBeEff033…5409dd`, asset USDG. First Robinhood Morpho candidate. Need live `asset()` / `convertToAssets` / confirm withdraw is not a queue.

### hliSLVR (watch — wrap liSLVR only if tax-free)

SLVR `0x791229E3…C29aD9` is a 1-minute grid lottery. Token has **2% buy/sell tax**. Never wrap or transfer SLVR. **liSLVR** vault `0xb06a7A96…41b3B` is the liquid claim: deposited SLVR is **permanently locked**; exit is sell the share. If and only if liSLVR is a clean ERC-20, Kind L: wrap the share, never `deposit` SLVR, never ve lock. ETH rake may harvest to HYPE. Unaudited. No adapter until the tax-free check is on-chain.

### hTWO (watch — no transferable stake receipt)

Twofold DualPool on Robinhood. TWO `0x2A4a33A2…88d5` (fixed 1B, no tax, ~$1.2M). **vTWO** `0x5c02401e…5950` is 1:1 vote wrap, unwrap anytime — occupancy. **StakingVaultV2** `0x06E463fD…B3A9` 1h unstake, TWO rewards. **TwoStakingUSDG** `0x9CF18bB1…E9e3` 7d unstake, USDG rewards. LP is ERC-1155. No L adapter. C2 only after a receipt exists.

### hSB (watch — NFT, not the ERC-20)

StonkBrokers on Robinhood 4663. **$STONKBROKER** `0xe934e36a…bf50` is a collection token: no yield, no tax, no on-contract staking. Stock-token drops go to **activated ERC-6551 broker NFTs** `0x539cdd04…abf0`. Activation burns STONKBROKER and resets on transfer. Geo attestation; project terms treat payouts as work, not yield. Do not wrap the ERC-20. NFT lockbox would also need TBA custody. No adapter.

### hSNX (parked)

420 Pool closed **2026-06-19**. SNX without debt returned. SIP-423 Phase 4 staking reform is **CONTRACT BUILD DEFERRED**. Official docs: previous SNX staking is not active. No inner. Do not wrap SNX.

### hUNCX (parked — same bucket as hGMX)

Staking rewards and buybacks paused **2026-08-21**. UNCX lockers still take fees (~$185M TVL, ~$180k annualized) but that is protocol revenue, not staker yield. No transferable earning receipt. Do not wrap UNCX.

### hstDYDX (later — Cosmos)

Do not wrap ethDYDX. Yield is validator stake on **dYdX Chain** (USDC fees, ~21–30d unbond, address-keyed). Liquid receipt is **Stride stDYDX**. Same class as hJupSOL: non-EVM lockbox first. Never undelegate from the lockbox.

### hsWBERA (batch 2 — Berachain mainnet, wrap sWBERA, 1% rate skim)

No Bepolia. LZ EndpointV2 is live on 80094. One listing this phase.

Live 2026-09-07: 1 sWBERA ≈ 1.458 WBERA. Vault `paused() = false`. Supply ~3.72e7.

| | |
| --- | --- |
| Canonical backing | transferable **sWBERA** pulled (`0x118D2cEe…eC9a` on **Berachain 80094**). Vault **is** the ERC-20. Asset = WBERA `0x6969…6969` |
| Accounting unit | 1 hsWBERA share. WBERA NAV lives in `convertToAssets` |
| Core invariant | L: `supply ≤ totalLocked sWBERA` + sWBERA supply ceiling |
| Proof source | lockbox `totalLocked` + `sWBERA.totalSupply` / `convertToAssets` |
| Rate source | `convertToAssets(1e18)` (`RateKind.ConvertToAssets`) + `retainRateYield`. Same 1% skim as hcbETH / hgSOON. Wrap/redeem settle the 1% first |
| Mint / redeem | wrap/unwrap **sWBERA** as ERC-20. Instant. **Never** native BERA / WBERA `deposit`/`mint`. **Never** the 7d unbond: `withdraw` 0xb460af94 / `redeem` 0xba087652 / `queueWithdraw` 0x50b3f984 / `queueRedeem` 0x9ad82aa0 / `completeWithdrawal` 0x38248a0c, 0x06866fdc / `cancelQueuedWithdrawal` 0x1b0aed2c. Cooldown **604800**. NFT `0x30e47fd0…99DA` |
| Yield | auto-compound in the sWBERA/WBERA rate (Incentive Auction WBERA). Protocol skims **1% of surplus**. Holders have no WHYPE claim. Do not pull sWBERA as side-token harvest |
| Failure | vault pause; someone `redeem`s lockbox shares (principal in 7d NFT); cancel remints at **current** rate |
| Auto-pause | ceiling / health / inner paused |
| Worst-case loss | min(cap, maxPerDay) on sWBERA. Unbond APY gap is not backing |
| Test | `testSwberaConvertToAssetsSameMathAsCbeth`, `LeafReceiptOnly`. Adapter never calls the 7d queue selectors. `ConfigureMainnetListing` `ASSET=hswbera` |
| Deploy | **Mainnet** `DeployAdapter` on 80094. Not Bepolia |



### hB3 (research — stake path live, yield incomplete)

| | |
| --- | --- |
| Canonical backing | B3 staked via `stakeFor(lockbox, amt)` on `0x18541`. **Principal then sits in EOA `0x8D06` (no code)** |
| Accounting unit | C1 ticker. No receipt token |
| Core invariant | HyperEVM hB3 ≤ inbound B3 we staked. We cannot prove EOA still holds it |
| Proof source | `Staked` event on 0x18541. **Not** `balanceOf(stake)` — tokens leave |
| Yield | upside.win delayed B3 on `0xe69b`. `claimDelayedWithdrawal(index)` `0xf41ba29c`. Live tx `0x087ce4a0` paid 252.67 B3 to stored recipient (Request ID 1431). **Not** a WIN ERC-20. Enable only if lockbox is both stake `user` and payout recipient |
| Failure | EOA moves B3; WIN paid to EOA not lockbox; games/spins on the stake account |
| Auto-pause | health. Do not mint if team wallet drained |
| Worst-case loss | all TVL (custodial). C1: no protocol peg-out |
| Test | do not ship until WIN claim is pinned. A row that says `hB3 ≤ B3.balanceOf(0x18541)` is **rejected** |

### hORDER (batch 4 — **Arbitrum only**, no CREATE2 twin)

Canonical economic owner is **the Orderly ledger account = the Arb lockbox address**. Orderly already keys by address across chains. HyperLeaf only *appears* on Arb, so one address is enough. CREATE2 twins are the same identity idea — unused here.

| | |
| --- | --- |
| Canonical backing | Orderly ledger **stake** keyed by that lockbox address. Physical custody is the farm/ledger. **Not** `ORDER.balanceOf(lockbox)`. **Not** VALOR. **Not** USDC |
| Accounting unit | ORDER principal on the ledger. 1 hORDER ≤ 1 verified ledger ORDER |
| Core invariant | HyperEVM hORDER supply ≤ `ledgerPrincipal` for this identity. `farmPrincipalOut` is a location flag only |
| Proof source | Guardian `reportLedgerPrincipal(observed)` after Orderly compose (eid 30213). After `stakeOrder`, `inner.balanceOf` is **0** and is not the proof |
| Mint / redeem | C1, market-only. Further mints halt until `ledgerPrincipal >= totalLocked`. Unstake types 2/3/4 owner-only. Harvest 10/17 public. **One source eid** (`30110` main / `40231` Arb Sepolia). Do not `openBridge` a Base/OP lockbox into this OFT |
| Inner | Arb ORDER OFT `0x4E200fE2…`. Never the Ethereum ERC-20 `0xABD4…` |
| Farm | Orderly proxy `0xC8A8Ce0A…`, `stakeOrder` `0x413aaa60`, `FarmStyle.AmountNative`. Request `sendUserRequest` `0xcec09c0d` |
| Yield | USDC (legacy 9→10) → HYPE. Occupancy: VALOR / esORDER (type 17). Do not vest |
| Failure | LZ to Orderly not credited; wrong-chain withdrawal; user inflating ledger report |
| Auto-pause | `reportLedgerPrincipal < totalLocked` → Degraded, mint stops |
| Worst-case loss | C1 TVL. First deposit after a gap is at-risk until the ledger report (bounded by `maxPerTx`) |
| Test | `test/lz/LeafOmnichainCreate2.t.sol`. Idle ORDER cannot be `pullYield`. `farmUnstake` disabled (async 2/3/4). Pins: withdraw 1196 `0xdd65ff33`; USDC 1.156 `0x93ec1d61`; type 17 `0x7a9676a6` |
| Deploy | `BATCH=4` `ASSET=horder` on Arb 42161. Mock ORDER + MockOrderlyProxy in forge tests |



### hLBTC (batch 3 — Ethereum, wrap LBTC, Bitwise covered-call rate)

Wrap **LBTC** `0x8236a870…` only. Never BTC.b, LBTCv, BTCe, Base LBTC, or native BTC. 10-day Lombard redeem is **not** called.

| | |
| --- | --- |
| Canonical backing | lockbox LBTC on Ethereum |
| Accounting unit | 1 hLBTC (18 dec) = 1 LBTC (8 dec) via `shareScale = 1e10` |
| Core invariant | dest shares / 1e10 ≤ lockbox LBTC − protocol 1% skim |
| Rate source | AssetRouter `getRate(LBTC)` `0x9eCe5fB1…`. **Admin/Bitwise**, not Babylon |
| Circuit | `maxRateJumpBps = 300` **up or down**. `pokeRate` latches `rateJumped` (mint tx would roll it back). Guardian `acknowledgeRate` sets watermark **without** taking the spike as 1%. Small down (≤3%) pins the watermark, no fee |
| Caps | `depositCap` = 0.05 LBTC inner (`5e6`). `setLimits` / OFT `supplyCap` = `5e6 * 1e10` share units. `INNER_SUPPLY_CEILING` = live `LBTC.totalSupply()` + headroom — **never** `5e6` |
| Mint / redeem | wrap/unwrap LBTC. Never `burn` / `mint(bytes,bytes)` / AssetRouter `deposit` / Bascule / 10d `redeem` |
| Yield | Covered-call premiums in the rate. 1% skim, 99% stays. Rally can lag BTC |
| Failure | Router lie / 10% overnight print; wrapping BTC.b / Base LBTC; using inner cap as dest share cap |
| Auto-pause | `rateJumped` → mint stops, redeem stays |
| Worst-case loss | 0.05 LBTC default cap |
| Test | `test/lz/LeafLbtc.t.sol`. `BATCH=3 ASSET=hlbtc` |

### hveAERO (later — NFT lockbox, not a grok-bot batch)

Fungible dest ticket **only** for **permanent NORMAL** veNFTs. Time-locked decaying positions cannot share one ERC-20 (Alice 4y vs Bob 1 week would steal duration).

| | |
| --- | --- |
| Canonical backing | veAERO NFTs in `LeafNftLockbox` on Base (`0xeBf418Fe…`). Principal = `locked(tokenId).amount` at wrap |
| Accounting unit | 1 hveAERO = 1 AERO locked in a **permanent** NFT. Not voting power. Not liquid AERO |
| Core invariant | dest supply ≤ sum of recorded `principalOf` ≤ on-chain `locked.amount` of held ids |
| Mint / redeem | C1, market-only (`LeafClosedOFT`). No protocol NFT return. No `createLock` of AERO |
| Accept | `escrowType == NORMAL`, `isPermanent`, not `voted`, `attachments == 0`. Reject LOCKED / MANAGED / decaying / tokenId 0 |
| Never | `merge` / `split` / `withdraw` / `unlockPermanent` / `vote` / wrap liquid AERO / `DeployClosed` |
| Yield | Rebase stays inside the NFT (NAV of the pool, no 1% skim until a split path exists). Bribe/fee ERC-20s on the lockbox → converter → HYPE 99/1. Never pull the NFT or AERO |
| Failure | Aerodrome unlocks permanent; we accepted a decaying/voted/attached NFT (code rejects); mixing veUP into this listing |
| Auto-pause | `reportNftHealth` (permissionless): unlock, amount drop, NFT left **or burned** (`ownerOf` revert) → Degraded. Owner `restoreHealth(Normal)` re-checks the same proof. `maxPrincipalPerNft` 100k AERO. `maxNfts` 64 |
| Worst-case loss | C1 cap. First-batch listing is **not** MainnetBatches (cannot `BATCH=n`). Scripts: `DeployNftLockbox` / `ConfigureNftListing` |
| Test | `test/lz/LeafNftLockbox.t.sol` |
| Same box later | hveUP (Robinhood) once veUP is the same permanent-lock shape. StonkBrokers / PTSMAX only if they have a comparable principal unit |



### PTSMAX

Accounting unit is **sRIVER_V2 tokenId**, not `balanceOf(Pts)`. Do not ship on the ERC-20 adapter. Merkle weekly Pts is address-keyed, not NFT-keyed. Blocked on NFT lockbox + lockbox appearing in a weekly tree.



### hsAVAX (next testnet — BENQI, same skim as hcbETH)

Wrap **sAVAX** `0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE` (Avalanche). Never AVAX. Never `requestUnlock` / `withdraw`.

| | |
| --- | --- |
| Canonical backing | lockbox sAVAX |
| Accounting unit | 1 hsAVAX share. Economic AVAX is `getPooledAvaxByShares` |
| Core invariant | L: `supply ≤ totalLocked sAVAX`. Rate harvest 1% skim only |
| Rate source | `getPooledAvaxByShares(1e18)` (`RateKind.GetPooledAvaxByShares`). Not `exchangeRate()` |
| Mint / redeem | wrap/unwrap sAVAX, instant. Official 15d unlock + 2d redeem is the user's problem after unwrap |
| Yield | Avalanche PoS already in the rate. BENQI takes 10% of validator rewards before that rate. HyperLeaf skims **1% of remaining surplus** (`retainRateYield`). Wrap/redeem settle the 1% before mint/payout. Holders have no WHYPE claim |
| Failure | BENQI rate lie; `requestUnlock` on the lockbox (forbidden). One cooldown per address — do not start it |
| Auto-pause | inner supply ceiling; guardian |
| Worst-case loss | min(depositCap, maxPerDay) on principal; 1% skim on converter |
| Test | `testSavaxPooledAvaxRateSameMathAsCbeth`, `testRewardsSelectorRejectsBenqiUnlock`. `BATCH=3` `ASSET=hsavax` |

Same math as hcbETH. Different 4-byte rate read.

### hstkwaUSDC (next testnet — Umbrella StakeToken, not stkAAVE)

Wrap **one address**: `stkwaEthUSDC.v1` `0x6bf183243FdD1e306ad2C4450BC7dcf6f0bf8Aa6` (Ethereum). `.v1` is a factory suffix. A later `.v2` is a different ERC-20 → new listing. Pin the address.

| | |
| --- | --- |
| Canonical backing | lockbox balance of that StakeToken. Underlying is waEthUSDC `0xD4fa2D31…`. Never aUSDC / USDC / other Umbrella stks |
| Accounting unit | 1 hstkwaUSDC = 1 stk share. Economic USDC is `convertToAssets` (can fall on slash) |
| Core invariant | L: `supply ≤ totalLocked stk`. Rate harvest must not drop backing below outstanding principal watermark |
| Proof source | lockbox `totalLocked` + `balanceOf(stk)` + `convertToAssets`. Side rewards are **not** backing |
| Mint / redeem | wrap/unwrap the v1 receipt, instant. **Never** `cooldown` / `redeem` / `withdraw` on StakeToken (20d, one cooldown per address). **Never** auto-migrate to v2. User who wants Aave v2: unwrap, migrate themselves |
| Yield | **Two books.** (1) aToken interest in `convertToAssets` → hcbETH `retainRateYield`, pull **1% of surplus** as protocol fee, 99% stays in backing. Slash / rate down → keep high-water mark, pull 0. Recovery to that mark is not fee. Guardian `acknowledgeRate` is the explicit loss-recognition path. (2) Umbrella emissions via `RewardsController` `0x4655Ce3D…` `claimAllRewards([stk], lockbox)` → converter → WHYPE 99/1. Pin selector from controller ABI, not a tx hash |
| Failure | Aave USDC deficit slash; governance upgrades implementation at same proxy; `.v2` migration (pause mint, keep redeem of v1); RewardsController mis-set to cooldown/redeem |
| Auto-pause | health on slash / inner supply ceiling; guardian pause mint if Aave announces v2 |
| Worst-case loss | slash of locked stk (Umbrella max is `totalAssets - MIN_ASSETS_REMAINING`) + converter slippage on side rewards |
| Test | cooldown/redeem selectors forbidden; `test/lz/LeafUmbrella.t.sol` claimAllRewards does not move stk; donation not yield; slash keeps high-water mark |

Do **not** treat this as hxSQUID. Poke target is the RewardsController, not inner.

### hSKY / hAAVE

Parked. A row that says `hSKY ≤ LSSKY balance` is **rejected**. Realizable value is SKY principal + rewards − USDS debt − penalties. **stkAAVE is HOLD** (legacy Safety Module, governance). Umbrella USDC is **hstkwaUSDC**, above.

## Global outflow

Inner leaving a lockbox ≤ **that** lockbox `maxPerDay` on redeem. Dest `maxPerDay` only bounds new hTokens. Set them equal.

## Claim calls

`pokeClaim` requires `setClaimCall(target, selector)`.
