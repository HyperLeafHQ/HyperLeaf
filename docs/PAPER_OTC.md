# Paper Escrow

Design GO 2026-10-13. Not a code GO. Not a deploy GO. Not Leaf Market and not hNEST.
Do not `createMarket` on `0x22684F6e…`. Path-1 / PR #96 is a separate product.

Code: `src/premarket/PaperOtcFactory.sol`.

PAPER `0xe40f17915DAa230324030003A197cdAEf2261C0e` (18 decimals).
USDM and sUSDM are the Monetrix pins in `PremarketAddresses`. On chain 999 the constructor rejects anything else.

`priceUsdmPerPaper` is USDM (6 decimals) per 1 PAPER (`1e18`).
Collateral is exactly 1× or 2× that payment.

Both sides deposit USDM. The factory wraps sUSDM and remembers the principal and the shares minted for that bag.

Exit pays that bag's USDM principal. Shares above the principal go to `feeRecipient`.
If the bag cannot redeem the full principal, the whole remaining share balance of that bag is returned. No partial top-up. Unstaking the returned sUSDM is the recipient's problem, and it is not a promise of the same USDM amount.

| Exit | Who | Result |
| --- | --- | --- |
| `cancelOffer` | Seller, while Open | Seller's bag back |
| `agreeMutual` | Both, while Matched | Each bag back to its depositor |
| `sellerWalk` | Seller, while Matched | Buyer receives both bags. Seller gets nothing |
| `timeoutCash` | Anyone, 180d after match | Each bag back. No penalty |
| `deliverPaper` + `settlePhysical` | Exact PAPER, then seller or buyer | PAPER to the buyer. Both bags to the seller |
| `finalizeSellerDefault` | Anyone, 48h of enabled-time, no delivery | Buyer receives both bags. No PAPER moves |

48h counts only while `paperTransfersEnabled` is true. Guardian `disableTransfers` pauses that clock. Cash exits do not use that clock.

Transfers start false. Owner proposes, guardian confirms with a non-zero tx-hash reference. The contract stores the reference and does not replay it. Guardian can turn transfers off alone. Owner cannot turn them on alone.

Pause blocks new create/take only. Windows are constants. `feeRecipient` changes after 2 days. The factory is not upgradeable.
