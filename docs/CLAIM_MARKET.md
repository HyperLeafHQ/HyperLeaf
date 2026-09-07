# Secondary claims (not a spot book)

HyperLeaf does **not** chase near-spot AMM depth in the first phase.
A thin pool with subsidy and IL is a fake book. The protocol already
refuses to guarantee a buyer (`GROK_BOT_FRONTEND.md`).

What *is* in scope later: a **peer-to-peer board for the Leaf itself**.

```
productive position  →  hAsset (the claim)  →  someone else bids on that claim
```

Internal name: **Claim Market**. Never “debt”, never “HyperLeaf lends”,
never “treasury fills the other side”.

## Do we need it for every ticker?

No. Instant-receipt L already has an exit (burn, LZ, unwrap). A 10%
discount on hxSQUID vs 1:1 redeem is an arb, not a market. The board
is for claims that **cannot** come home today.

| Exit (GitHub) | Face value | Maturity | Yield that transfers with the Leaf | Board useful? |
| ------------- | ---------- | -------- | ---------------------------------- | ------------- |
| instant-receipt, **share-price** (`hcbETH`, `hsWBERA`, `hgSOON`, Morpho) | remaining inner / shares (`SOLVENCY` row) | LZ + official unwrap, not HyperLeaf | **Yes** (in the receipt) | Optional RFQ. Discount ≈ LZ + wait. Do not seed an AMM to look busy. |
| instant-receipt, **Rewarder** (`hxSQUID`, later hKAITO airdrops) | inner 1:1 (xSQUID) | same | **No** — pending HYPE stays with the seller address | Board can trade the Leaf. Publish that HYPE does **not** ride along. Do not invent a bundled “principal + future QUID” NFT until Rewarder ownership is explicit. |
| 只能卖掉 / C1 (`hVIRTUALMAX`, `BLUAI4Y`, `hORDER`, parked `hSKY`) | `SOLVENCY` accounting unit (often not `balanceOf`) | **never** via protocol redeem | per that row | **This is the product.** Bid is a liquidity price, not a depeg. |
| 烧掉后等几天 / C2 / hNEST | queued inner; ticket after burn | `eta` / Nest window | none after burn (Leaf is gone) | Board **before** burn (Leaf still exists). After burn there is a ticket, not a Leaf — different object, do not mix. |
| ve-NFT / locked | position NAV for that tokenId | lock end / epoch | occupancy ≠ principal | Board only after NFT lockbox exists. |

LP of a **share-price** Leaf already keeps intrinsic yield. LP of a
**Rewarder** Leaf does not get HYPE. We are **not** forcing gauges or
whAsset to fix that. If someone LPs hxSQUID they get the pair’s trading
fees, not HyperLeaf HYPE. That is accepted.

## Three rules if/when it ships

1. **Face is the SOLVENCY row**, not a USD oracle we invent. Quote as
   `bid / face` in the listing’s accounting unit (cbETH remaining, xSQUID,
   ORDER ledger principal, …). Record `execution / face / maturity`.
2. **No fill, no trade.** HyperLeaf treasury does not bid. A 30%
   standing discount is information, not a bug, and not a reason to
   print protocol-owned inventory.
3. **The sold object is the Leaf (or a C2 ticket), already transferable.**
   The board is matching, not a new claim token. Do not wrap a second
   “claim receipt” on top of hAsset.

## What we are not building in this commit

No order book. No AMM. No discount vault. No preview UI. The interface
is this file plus the existing `exit` / yield columns. A later listing
that cannot redeem (C1) should be able to sit on a board without new
Solidity on the wrap path.

## Hard constraints before any board Solidity

Do **not** ship a marketplace contract until these are tests, not just prose
(Luna `239ce2f` review):

1. **Rewarder HYPE stays with the seller address.** After `transfer`,
   `pending(seller)` equals `pending(seller)` from before the transfer.
   Buyer / escrow / AMM start at 0 for already-notified HYPE.
   `testEscrowHopDoesNotMovePendingHype`.
2. **No second claim token.** Escrow that holds a Leaf is an ordinary holder.
   It does not mint a “claim receipt”. Total Leaf supply must not increase
   because the token sat in a market contract.
3. **Face is the listing’s SOLVENCY unit**, typed, never a USD oracle and
   never `balanceOf(hORDER)` when the row is `ledgerPrincipal`.
4. **Discount copy follows health.** `Normal` → 流动性价格. `Degraded` /
   stale proof → 风险提示. `Insolvent` → 底仓有问题，不是普通折价.
   Frontend: `GROK_BOT_FRONTEND.md`.

The board is matching on the existing Leaf. HyperLeaf does not take the
other side.

## Wrap-fill (the actual product)

Early Leaf books will be thin. Do **not** seed an AMM. The board is a
**wrap redirect**: someone who was going to deposit inner, instead buys a
resting Leaf.

Example, C1 `BLUAI4Y`:

```
Seller holds 100 hBLUAI4Y, wants out at 70 BLUAI.
Seller transfers 100 Leaf into the board contract. Ask = 70 BLUAI.

Buyer was about to wrap 70 BLUAI → mint 70 new Leaf.
Instead they fill:
  70 BLUAI  →  seller (source chain)
  100 hBLUAI4Y (already minted) → buyer (HyperEVM)
```

No new Leaf. Lockbox `totalLocked` does not move. The 100 Leaf is still
backed by whatever was locked when the seller originally wrapped. The 70
BLUAI never becomes extra backing — it is the purchase price.

That is a sale of the claim, **not a loan**. HyperLeaf does not sit on
either side. Names: 转让 / wrap-fill. Never 债务, never 不良资产包,
never “HyperLeaf 接盘”.

### Who has the edge

Seller sets the ask (pricing power). Buyer has the scarce thing (inner
that can wrap). Treat it as a **buyer’s market**:

- Buyer rebate: **1% of the ask**, paid in the inner they just spent.
  Seller listed 70 → seller receives 69.3 BLUAI, buyer gets 0.7 BLUAI
  back. Effective 69.3 inner for 100 Leaf.
- Protocol does **not** take that 1%. Protocol take is occupancy (below).

If nobody fills, nothing happens. Cancel returns the Leaf. No treasury bid.

### Protocol revenue = occupancy, not the spread

Leaf that sits in the board is just another address.

| Yield type | While listed | On cancel (took it back) | On fill |
| ---------- | ------------ | ------------------------ | ------- |
| **Rewarder** (`hxSQUID`, BLUAI extra inner → HYPE, hORDER harvest) | Notify HYPE accrues to the **board address**. Board `claim()` → protocol. Seller already-notified HYPE stays on the seller (invariant). | Protocol keeps what notified while listed. Seller walks with Leaf, no extra cut. | Same occupancy HYPE already claimed or sitting on the board. |
| **Share-price** (`hcbETH`, `hsWBERA`, Morpho) | NAV stays **in the token**. Cancel = seller takes the richer receipt. Protocol gets **zero**. | This is the hole. | Spread is seller’s; protocol still zero unless we add a bond. |

So: as long as Leaf has left the seller’s wallet, they do not get Rewarder
HYPE. That match the rest of the protocol. Share-price does not work that
way — the receipt is the yield.

**v1 lists C1 only** (`BLUAI4Y`, `hVIRTUALMAX`, `hORDER`, …). Those cannot
unwrap; the board is the product. Instant-receipt share-price already has
烧掉就能拿回 — a 30% ask there is usually an arb, and cancel earns the
seller the NAV for free.

If a share-price ticker is listed later, occupancy must be a **maker bond**
in WHYPE (posted on list, returned on fill, protocol keeps a slice on
cancel). Do not skim the receipt itself. Do not pretend hanging hcbETH in
the board is a protocol fee.

### Fill path (when we write it)

Source adapter, not a second OFT:

1. Seller: `list(amountLeaf, askInner, sourceRecipient, deadline)` — Leaf
   moves to the board on HyperEVM. Face = SOLVENCY unit of that listing.
2. Buyer on source: `fill(orderId)` with `askInner` of the **canonical
   inner**, not USDC, not another ticker.
3. Source pays inner to `sourceRecipient` minus 1% rebate to buyer.
4. LZ message to dest: release Leaf from board to buyer. **Do not mint.**
5. Failure: inner stays escrowed on source until dest ack, or the fill
   reverts both legs. No half-state. No extra Leaf.

Caps / health / listingTag of a wrap still apply to a fill (same blast
radius). `Degraded` fill is allowed for C1 (it is the only exit) but UI
must not call the discount ordinary liquidity.

### Still not this commit

No board Solidity. The wrap path must not grow a `fill` hook until the
tests below exist, including `totalSupply` unchanged across a fill.

Additional tests before code:

5. Fill does not mint and does not change `totalLocked`.
6. Occupancy HYPE on a Rewarder ticker is claimable by the board, not the
   seller.
7. Cancel on a share-price ticker returns the same Leaf amount (NAV stays
   in the token) — which is why it is not v1.


