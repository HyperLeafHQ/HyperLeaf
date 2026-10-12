# Paper Escrow

Design GO 2026-10-13. Not a code GO. Not a deploy GO. Not Leaf Market and not hNEST.
Do not `createMarket` on `0x22684F6e…`. Path-1 / PR #96 is a separate product.

Code: `src/premarket/PaperOtcFactory.sol`.

PAPER `0xe40f17915DAa230324030003A197cdAEf2261C0e` (18 decimals).
USDM and sUSDM are the Monetrix pins in `PremarketAddresses`. On chain 999 the constructor rejects anything else.

`priceUsdmPerPaper` is USDM (6 decimals) per 1 PAPER (`1e18`).
Collateral is exactly 1× or 2× that payment.

Both sides deposit USDM. The factory wraps sUSDM and remembers the principal and the shares minted for that bag.

A covered exit transfers the sUSDM shares that redeem the booked USDM principal. The recipient unwraps. This contract never calls sUSDM `withdraw` or `redeem`.
Surplus shares go to `feeRecipient`.
If the bag cannot cover its principal, the whole remaining share balance of that bag is returned. No top-up. Returned shares are not a promise of the same USDM amount.

| Exit | Who | Result |
| --- | --- | --- |
| `cancelOffer` | Seller, while Open | Seller's bag back |
| `agreeMutual` | Both, while Matched | Each bag back to its depositor |
| `sellerWalk` | Seller, while Matched | Buyer receives both bags. Seller gets nothing |
| `timeoutCash` | Anyone, 180d after match, transfers off at call time | Each bag back. No penalty. Blocked only *while* transfers are on — see the correction below |
| `deliverPaper` + `settlePhysical` | Exact PAPER, then seller or buyer | PAPER to the buyer. Both bags to the seller |
| `finalizeSellerDefault` | Anyone, 48h of enabled-time, no delivery | Buyer receives both bags. No PAPER moves |

48h counts only while `paperTransfersEnabled` is true. Guardian `disableTransfers` pauses that clock. Cash exits do not use that clock.

Correction (2026-10-12): `timeoutCash` checks `paperTransfersEnabled` at call time and 180 days of **wall-clock** since `matchedAt`. A guardian `disableTransfers` after a match therefore reopens `timeoutCash` and CAN erase a pending or matured 48h default, converting the buyer's double-bag default claim into a no-penalty split. The earlier wording ("cannot erase a 48h default") was wrong. Whether default maturity should latch (survive a later disable) is an OPEN DESIGN DECISION.

Transfers start false. Owner proposes, guardian confirms with a non-zero tx-hash reference. The contract stores the reference and does not replay it. Guardian can turn transfers off alone. Owner cannot turn them on alone.

`transferProofRef` is stored, not verified. An EOA-to-EOA transfer does not prove the factory contract itself can receive and send PAPER. Recommended ops rule: the guardian confirms only after evidence that the factory address itself can move PAPER (e.g., a dust delivery rehearsal on a matched test offer), or explicitly accepts the residual risk.

Pause blocks new create/take only. Windows are constants. `feeRecipient` changes after 2 days. The factory is not upgradeable.

## External dependency risk (chain state as of 2026-10-12)

### PAPER transfer policy

PAPER `0xe40f17915DAa230324030003A197cdAEf2261C0e` is a TransparentUpgradeableProxy whose transfers currently revert `TransferRestricted()` for every address except the privileged `stakingContract` (`0xAAd6…F016`, holding ~98.9% of supply). The PAPER owner contract (`0xB915…`) can rotate that privileged sender at any time with no on-chain timelock. Three scenarios:

1. **Policy closed (today):** `deliverPaper` cannot succeed until the policy opens. The two-key enable gate (owner proposes, guardian confirms) exists for exactly this reason — do not confirm enablement without evidence per the `transferProofRef` ops rule above.
2. **Policy re-restricts while an offer is Delivered:** `settlePhysical` reverts on the final PAPER transfer to the buyer, and every other exit requires Matched. Both sUSDM bags and the delivered PAPER are permanently locked — no escape hatch exists today. OPEN DESIGN DECISION: a mutual-cancel-from-Delivered returning PAPER to the seller and both bags to their depositors is the candidate fix.
3. **Policy re-restricts while Matched:** sellers are defaulted after 48h of enabled-time through no fault of their own (delivery reverts, the clock keeps accruing). A guardian `disableTransfers` pauses that clock — and, per the correction above, reopens the 180d `timeoutCash`.

### Monetrix trust surface

sUSDM is a UUPS proxy. Its operator pause reverts `transfer`/`deposit` — a Monetrix pause freezes every factory exit (all exits move sUSDM shares). Upgrades can change `deposit`/`convertToAssets`/`previewWithdraw` semantics: if `previewWithdraw` ever reverts, `_payBag`'s catch arm returns whole bags to the parties and the fee scrape silently stops (user-favorable, protocol revenue zero). NAV is operator-priced via `injectYield`. Unwrapping is only via the Monetrix cooldown flow — this contract never calls `withdraw`/`redeem` (they revert `UseCooldownFunctions`). USDM is likewise UUPS + pausable (no blacklist observed); a USDM pause blocks create/take only, not exits.
