# HYPE rewards vs composability

Answers the three questions on `LeafHypeRewarder` after `b295c27`. Code that
changed: transfer hooks are try/catch; listing id is one-shot and
`register` requires OFT already pointing at this rewarder. The **allocation
rule did not change**.

## 1. Can HYPE be composable with LP / lending without breaking already-notified ownership?

**Not with the current distributor, and not by making yield “follow the token”.**

Today:

```
notify 99%
  ÷  hToken.totalSupply()   ← every address, including pairs and pools
claim()                     ← only that address
```

Already-notified yield is settled onto the holder **address** on transfer.
That part is correct (seller keeps what already accrued).

The leak is **later** `notify` calls: LP’d / lent / CEX’d supply still sits
in the denominator, the slice is booked to a contract that never `claim`s,
and wallet APR is strictly below 99% × yield / supply.

Three models:

| | Wallet hold | Uniswap v2/v3 LP | Lending pool | Transfer liveness |
| --- | --- | --- | --- | --- |
| **A — now** address + `totalSupply` | earns | pair eats the slice, LPs get 0 | pool eats the slice | hooked |
| **B — yield follows token** | earns | pair still holds pending; Uniswap never claims; **worse** (already-notified leaves with the LP add) | same | still hooked |
| **C — merge HYPE into Leaf NAV** | Leaf price ↑ | LP value includes it | pool share includes it | no rewarder |
| **D — stake-to-earn** (Chef `user.amount`) | opt-in | not in denominator unless a gauge | wrapper can stake | **no hook** |

- **B does not fix LP.** Uniswap cannot `claim`. Moving pending with the
  token just donates already-earned HYPE to the pair.
- **C is already how inner yield works** (hcbETH rate surplus). It is the
  wrong home for **WHYPE**. Burning a Leaf must return inner (or remaining
  inner), not a blend of inner + HYPE. Do not fold protocol HYPE into the
  receipt.
- **D is the only model that both (i) stops AMM from taxing wallet APR and
  (ii) lets a lending adapter pass HYPE through** (pool wrapper stakes, claims,
  splits). Wallet UX becomes “wrap then stake” or auto-stake on mint with
  unstake-on-transfer — which is A again for people who don’t stake.

Until D or a gauge ships: **say 99% is allocated, not received.** Do not
print wallet APR = 99% × harvested / supply. Do not ship “做 LP 也能领
HYPE”. Trap is `testPairShareStaysUnclaimed`.

Do **not** recover trapped WHYPE from `code.length > 0` addresses: that
steals from Safes and from any pool that later integrates `claim`.

## 2. Can LeafOFT transfers stay live if the rewarder is broken?

**Yes, now.** `LeafOFT._update` wraps `settle` / `updateDebt` in `try/catch`.
A bricked or mis-registered rewarder emits `RewardsHookFailed` and the ERC20
transfer still commits. Tests: `testBrokenRewarderDoesNotBrickTransfer`.

Owner may `setHypeRewarder(address(0), listingId)` to unhook. `listingId`
itself is frozen after first set.

Do **not** auto-disable the hook on the first failure: a caller with a tight
gas stipend could grief every holder.

Cost: one failed transfer can leave that user’s debt stale. Rewards for that
one hop may be wrong. Availability of the ticker is the higher invariant.

## 3. Can a reward pool be bound to exactly one listing?

**Yes, now, as an owner-config check, not a zk proof.**

Order is mandatory:

```
OFT.setHypeRewarder(rewarder, listingId)   // listingId one-shot
Rewarder.register(listingId, OFT)          // requires OFT.rewarder==this
                                           // and OFT.listingId==id
                                           // and token not already registered
```

`idOfToken[hToken]` prevents one OFT under two pool ids.
`ListingIdFrozen` prevents rewriting hKAITO’s OFT onto hSQUID’s id.

This does **not** bind to `AssetCatalog` / `listingTag` on the source
adapter. That remains an ops checklist (`GROK_BOT_TESTNET.md`). Owner can
still point an OFT at a *new* rewarder with the same id (replace a bricked
distributor). They cannot change the id.

## Dust / keeper

`minNotify(id)` is the smallest WHYPE amount `notify` will take at current
supply. Below that: `DustNotify`, funds stay with the keeper. Batch until
`amount >= minNotify`. Do not spin the cron on revert.

## What this commit is not

Not a new yield model. Not a gauge. Not “HYPE follows LP token”. Product
choice for D waits on the human. Frontend copy stays: wallet hold earns
later HYPE; LP / lend / CEX do not.
