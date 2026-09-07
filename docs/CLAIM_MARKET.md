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

No AMM. No discount vault. No preview UI. No treasury bid. The wrap
path does not grow a fill hook.

`LeafClaimEscrow` + `LeafClaimFill` are the board. Tests: fill does not
mint; occupancy HYPE → protocol; cancel has no fee; LZ ask-mismatch
refunds the buyer.

## Hard constraints (tests, not just prose)

Luna `239ce2f` / wrap-fill:

1. **Rewarder HYPE stays with the seller address.** `testEscrowHopDoesNotMovePendingHype`, `testSellerKeepsHistoricalHypeOccupancyToProtocol`.
2. **No second claim token.** Fill does not mint. `testFillLocalBuyerRewardNoMint`.
3. **Face is the listing’s SOLVENCY unit**, never a USD oracle.
4. **Discount copy follows health.** Frontend: `GROK_BOT_FRONTEND.md`.
5. **Cancel is free.** Occupancy HYPE already notified stays with the board.
6. **Ask mismatch refunds the buyer.** `testLzWrongAskRefunds`.


## Wrap-fill (the actual product)

Early Leaf books will be thin. Do **not** seed an AMM. The board is a
**wrap redirect**: someone who was going to deposit inner, instead buys a
resting Leaf.

Seller sells **exit**. Buyer sells **liquidity**. Protocol is escrow only.

```
Seller ───────── Buyer
           │
      protocol escrow
```

Never: Seller → HyperLeaf treasury, never HyperLeaf → Buyer.

Example, C1 `BLUAI4Y`:

```
Alice: 100 hBLUAI4Y into escrow. Ask = 70 BLUAI.
Bob was about to wrap 70 BLUAI.
Fill:
  69.3 BLUAI → Alice
  0.7 BLUAI  → Bob   (buyer reward, 1% of ask — not a protocol fee)
  100 Leaf   → Bob   (already minted)
```

Discount = 30% is **C1 secondary liquidity price**, not a depeg.
No new Leaf. `totalLocked` does not move.

### Buyer reward, not a fee

The 1% is **Buyer Reward** (liquidity incentive). Protocol take is **not**
the spread and **not** an execution fee (execution fee = 0).

### Protocol revenue = occupancy time

While Leaf sits in escrow it is just another address. Rewarder HYPE that
notifies during the wait accrues to the escrow and `claimOccupancy` →
protocol. Already-notified HYPE stays with the seller (`testEscrowHop`).

Cancel / expire returns the Leaf. **No cancel fee.** If Alice lists, waits,
cancels, protocol income from that order may be 0 (unless a notify landed
while listed). That is healthy: we earn from occupied capital, not from
punishing a seller who did not consume a buyer.

Share-price Leaf (hcbETH): NAV stays in the token. Cancel = seller takes
the richer receipt; protocol gets 0. **Do not force a fee to “fix” that.**
v1 allowlists **C1 only**. Escrow yield accounting for auto-compounding
is a later model, not a Rewarder hack.

Rights freeze at `list`: seller accepts “收益停止”. Fill later does not
retro-credit them.

### Contracts

- `LeafClaimEscrow` (dest): list / cancel / expire / fillLocal / occupancy claim
- `LeafClaimFill` (source): lock inner, LZ FILL → dest releases Leaf → ACK pays
  99/1, or REFUND if the order is gone / ask mismatch

Status: `OPEN → FILLED | CANCELLED | EXPIRED`

### Fill path

1. `list` — Leaf to escrow. Face = SOLVENCY unit.
2. Source `fill` — exact `wantAmount` of canonical inner.
3. Dest verifies ask + `sourceRecipient`; releases Leaf; **does not mint**.
4. ACK pays seller 99% + buyer reward 1%. Failure → REFUND inner to buyer.

`Degraded` fill is allowed for C1 (only exit) but UI must not call the
discount ordinary liquidity.


