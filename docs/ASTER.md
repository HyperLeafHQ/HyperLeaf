# ASTER — BSC asTokens yes; $ASTER / Aster Chain no

Verified 2026-09-10 against [Aster contracts](https://docs.asterdex.com/overview/smart-contracts) and [Aster Chain staking](https://docs.asterdex.com/aster-chain/staking.md).

## Do not wrap $ASTER

BSC token `0x000Ae314E2A2172a039B26378814C252734f556A` is the **spot** BEP-20 (8e9 max). Yield is **veASTER on Aster Chain** (mainnet Mar 2026): lock up to 208 weeks, loyalty + fee buyback. Not a transferable BSC receipt. Aster Chain is their L1 for perps — not a Leaf listing.

## BSC first: asTokens, not $ASTER

Official Earn still on BSC, mint not paused:

| Token | Address | Live supply | Inner |
| --- | --- | --- | --- |
| **asBNB** | `0x77734e70b6E88b4d82fE632a168EDf6e700912b6` | ~107,315 | slisBNB (Lista clisBNB + Binance Launchpool NAV). Withdraw **always slisBNB**. |
| asCAKE | `0x9817F4c9f968a553fF6caEf1a2ef6cF1386F16F7` | ~40,932 | veCAKE. Minting was closed. |
| asUSDF / asBTC | docs list | — | later C2 |

asBNB mint `0x2F31ab8950c50080E77999fa456372f276952fD8`, `paused()==false`. HyperEVM has **no** code at the asBNB address.

asBNB is **hslisBNB + extra layer**. Lista slisBNB first (`feat/hslisbnb-rate`, after hgSOON). asBNB after that, never instead, never native BNB.

Hodler/Megadrop airdrops are **claimable asBNB**, not share-price. Same rule as PYUSD subsidy: only NAV we skim.

`NotThisBatch`.
