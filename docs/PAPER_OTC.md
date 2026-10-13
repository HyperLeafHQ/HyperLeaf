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
| `timeoutCash` | Anyone, 180d after match, and only if that offer's delivery cycle has not started | Each bag back. No penalty |
| `deliverPaper` + `settlePhysical` | Exact PAPER, then seller or buyer. No deadline on settle | PAPER to the buyer. Both bags to the seller. If the PAPER transfer reverts, the offer stays Delivered and can be retried |
| `finalizeSellerDefault` | Anyone, 48h of enabled-time, transfers on, no delivery | Buyer receives both bags. No PAPER moves |

48h counts only while `paperTransfersEnabled` is true. Guardian `disableTransfers` pauses that clock so the flow can wait and resume. It does not reopen a 180-day refund whose delivery cycle has already started.

Signed 2026-10-13:

- No Delivered refund. PAPER already in the contract cannot move while the token restricts transfers, so an exit that tries to send it back would fail the same way. `settlePhysical` waits until the transfer succeeds.
- While an offer is Matched, guardian turns transfers off to pause the 48h clock if PAPER re-restricts. Otherwise that clock keeps running and the seller can be defaulted.
- The 180-day refund dies for an offer the moment its 48h cycle starts (transfers were already on at match, or they are turned on later). A later `disableTransfers` does not bring it back.
- v1 guardian is not rotatable.

Transfers start false. Owner proposes, guardian confirms with a non-zero tx-hash reference. The contract stores the reference and does not replay it. Guardian can turn transfers off alone. Owner cannot turn them on alone.

`transferProofRef` is stored, not verified. An EOA-to-EOA transfer does not prove the factory contract itself can receive and send PAPER. Recommended ops rule: the guardian confirms only after evidence that the factory address itself can move PAPER (e.g., a dust delivery rehearsal on a matched test offer), or explicitly accepts the residual risk.

Pause blocks new create/take only. Windows are constants. `feeRecipient` changes after 2 days. The factory is not upgradeable.

## External dependency risk (chain state as of 2026-10-12)

### PAPER transfer policy

PAPER `0xe40f17915DAa230324030003A197cdAEf2261C0e` is a TransparentUpgradeableProxy whose transfers currently revert `TransferRestricted()` for every address except the privileged `stakingContract` (`0xAAd6…F016`, holding ~98.9% of supply). The PAPER owner contract (`0xB915…`) can rotate that privileged sender at any time with no on-chain timelock. Three scenarios:

1. **Policy closed (today):** `deliverPaper` cannot succeed until the policy opens. The two-key enable gate (owner proposes, guardian confirms) exists for exactly this reason — do not confirm enablement without evidence per the `transferProofRef` ops rule above.
2. **Policy re-restricts while an offer is Delivered:** `settlePhysical` reverts on the PAPER transfer and the offer stays Delivered. There is no refund. Retry `settlePhysical` when the token allows transfers again. Both bags stay locked until then.
3. **Policy re-restricts while Matched:** guardian `disableTransfers` pauses the 48h clock so the seller is not defaulted for a transfer they cannot make. Turning transfers back on resumes the remaining time. The 180-day refund does not return if this offer's delivery cycle had already started.

### Monetrix trust surface

sUSDM is a UUPS proxy. Its operator pause reverts `transfer`/`deposit` — a Monetrix pause freezes every factory exit (all exits move sUSDM shares). Upgrades can change `deposit`/`convertToAssets`/`previewWithdraw` semantics: if either quote reverts, `_payBag` returns the whole bag to the party and the fee scrape stops for that bag (user-favorable, protocol revenue zero). NAV is operator-priced via `injectYield`. Unwrapping is only via the Monetrix cooldown flow — this contract never calls `withdraw`/`redeem` (they revert `UseCooldownFunctions`). USDM is likewise UUPS + pausable (no blacklist observed); a USDM pause blocks create/take only, not exits.
