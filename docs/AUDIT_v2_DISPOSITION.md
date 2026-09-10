# Audit v2 disposition — comment 5622322621

Baseline `b4fbfc9`. Reply to Luna so this does not re-open as if live Nest/Gate are broken.

| ID | Verdict | Why |
| --- | --- | --- |
| H-1, H-2b, H-3, H-5, LeafOFT freeze | already fixed | no further work |
| **H-2a** | **fixed on next NestVault source** | Stop minting fee shares in `bookVerifiedYield`. Adapter yield can still raise NAV (10%/week cap) and be written down; fees cannot be clawed. **Live vault `0x4f66…` is immutable v1 and does not run this path.** Remaining realize-then-book (NAV only on cash NEST) is next-vault, not a live incident. |
| **H-4** | **won't change** | Live Gate `0xE1b8…` is not upgradeable. `claim()` is one tranche per call by design; `claimTranche` exists. 32-cap is a gas bound (`TooManyTranches`). Residual dust is rounding on the last wei, not a drain. Do not redeploy Gate for this. |
| M-1 | won't change | `harvest()` fees realized HEV HYPE; `_updateHypeAccumulator` is leftover-balance. Donations increase holder HYPE, not a theft path. Revisit only if a new harvest mode is added. |
| M-2 | won't change | `lastAccounted = 0` when `bal <= reserved` under-accounts (no extra protocol fee). No exploit in the current convert-to-hype call path. |
| M-3 | won't change | Shared day cap is the product: one address can fill `maxPerDay`. Per-user quota is a new design, not a bugfix. |
| SPOLAdapter | PASS | no code |
| GTStakingAdapter | scaffold only | not on `main`; do not treat `staked+pending` as NAV |
| VVV N-1 | fixed | `totalAssets` = staked + idle VVV. `pendingRewards` only after `harvest()` |
| VVV N-2 | fixed | `finalizeWithdraw` pays the unstake delta, not the whole wallet |
| VVV N-3 | fixed | `forceApprove` / `safeTransfer` |

Do not re-audit H-4/M-1/M-2/M-3 as open P0/P1 on live contracts.
