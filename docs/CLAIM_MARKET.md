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

