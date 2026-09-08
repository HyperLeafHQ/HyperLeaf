# Exit board (not a DEX)

> HyperLeaf does not provide liquidity. It provides an exit venue for otherwise illiquid claims.

Not an AMM. Not a matching engine. Not treasury inventory. On-chain
escrow + a frontend that reads `orders[id]`. Seller lists, buyer fills
that id. No RFQ, no oracle, no keeper matching.

Three things the contracts must keep:

1. **Protocol never bids.** `OPEN → FILLED | CANCELLED | EXPIRED`. No fill, no trade.
2. **The order is an unambiguous swap.** `Filled(id)` means buyer got exact `leafAmount`, seller got exact `wantToken × 99%`, buyer got exact `wantToken × 1%` (buyer incentive, not a protocol fee). No mint, no lockbox change, no second claim, no other token.
3. **Ask is frozen at `list`.** Expiry ≤ 90 days. Occupancy HYPE while listed → protocol. Seller keeps already-accrued HYPE.

C1 is the **only** protocol exit. hNEST on this board is an *early* exit before the official window — different product, same contracts, `fillLocal`. Do not market them as the same “spot sell”.

Internal name: **Claim Market**. Never “debt”, never “HyperLeaf lends”,
never “treasury fills the other side”.

## Do we need it for every ticker?

No. Instant-receipt L already has an exit (burn, LZ, unwrap). A 10%
discount on hxSQUID vs 1:1 redeem is an arb, not a market. The board
is for claims that **cannot** come home today.

| Exit (GitHub) | Face value | Maturity | Yield that transfers with the Leaf | Board useful? |
| ------------- | ---------- | -------- | ---------------------------------- | ------------- |
| 只能卖掉 / C1 (`hVIRTUALMAX`, `BLUAI4Y`, `hORDER`, parked `hSKY`) | `SOLVENCY` accounting unit (often not `balanceOf`) | **never** via protocol redeem | per that row | **Priority 1.** This is the product. |
| hNEST (6-month window) | NEST (same chain) | `requestWithdraw` ~26w | residual HYPE follows address | **Priority 2.** Same escrow, `fillLocal`. Board **before** `requestWithdraw`. After burn there is a ticket, not hNEST — do not mix. |
| 烧掉后等几天 / C2 | queued inner | `eta` | none after burn | Board **before** burn only. Same contracts as C1 if you allowlist. |
| instant-receipt, **share-price** | remaining inner | LZ + official unwrap | in the receipt | **Plug only.** `setMarket` + existing fill. No escrow yield model. Cancel = seller keeps NAV. Skip if anyone would have to write extra code. |
| instant-receipt, **Rewarder** (`hxSQUID`) | inner 1:1 | same | HYPE does not ride | Optional. Instant redeem is usually better than a 30% ask. |
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
   The board is matching, not a new claim token. DEX one-sided LP is the
   advanced DIY path (fees, no HYPE). The board is the simple path (no
   fees, no HYPE, 1% of ask to the buyer). Do not wrap a second receipt.

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


**v1 allowlist**

1. Closed C1 (`BLUAI4Y`, `hVIRTUALMAX`, `hORDER`, …) — `LeafClaimFill` on source.
2. hNEST — `fillLocal` on HyperEVM (pay NEST, receive hNEST). No NestVault changes. Residual HYPE occupancy is whatever already follows the holder address; do not add a Nest-specific claim path until it is a one-line `claimOccupancy` plug.
3. Share-price / other Liquid — **no new Solidity.** Owner `setMarket` if they want; otherwise leave off. Instant unwrap already exists.

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
No extra Solidity. Owner may `setMarket` later; default is off.

hNEST uses `fillLocal` (same chain). Do not fork NestVault for occupancy.

Rights freeze at `list`: seller accepts “收益停止”. Fill later does not
retro-credit them.

### Contracts

- `LeafClaimEscrow` (dest): list / cancel / expire / fillLocal / occupancy claim
- `LeafClaimFill` (source): lock inner, LZ FILL → dest releases Leaf → ACK pays
  99/1, or REFUND if the order is gone / ask mismatch

Status: `OPEN → FILLED | CANCELLED | EXPIRED`

Handshake (C1):

```
fill → dest FILL (+ prepaid native for return) → ACK → pay 99/1
fill mismatch / cancelled → REFUND
abort (buyer after 3d, guardian now) → dest still Open: ABORT_OK
                                 → dest already Filled: ACK
retryAck / retryRefund if a return message is dropped
```

Inner never moves until ACK / REFUND / ABORT_OK. Fill does not mint.
One LZ peer per deploy (`remoteEid` frozen). Extra chains = new escrow.
`list`/`fill` reject amounts above uint128 before transfer. `retryRefund`
is permissionless — seller cancel does not need to pay LZ.

1. `list` — Leaf to escrow. Face = SOLVENCY unit.
2. Source `fill` — exact `wantAmount` of canonical inner.
3. Dest verifies ask + `sourceRecipient`; releases Leaf; **does not mint**.
4. ACK pays seller 99% + buyer reward 1%. Failure → REFUND inner to buyer.

`Degraded` fill is allowed for C1 (only exit) but UI must not call the
discount ordinary liquidity.


