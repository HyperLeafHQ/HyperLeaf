# Peg rules (Liquid, 7 Sep 2026)

L-BTC was not a stolen key. A range-proof cache did not bind **asset type**. Fake receipts took a normal peg-out. The federation signed. Real BTC left.

HyperLeaf is the same shape: lockbox is the reserve, Leaf ticker is the receipt, LayerZero is the proof, redeem is the peg-out. These rules are **code**, not slogans.

## 1. Minted shares ≤ realizable backing

Each listing has its own lockbox and its own `listingTag`. A HyperEVM OFT will not mint past `supplyCap`. A source lockbox will not lock past `depositCap`. Set them equal.

## 2. Redeem pays cash, not a receipt

Burning a Leaf does not move inner tokens by itself. The source `_lzReceive` / `claim` calls `_requireCash`. If the box cannot pay, it reverts. Pause is not a substitute for this check.

## 3. Halt before money leaves

`GUARDIAN` can `pause` and `closeBridge`. Guardian cannot unpause or reopen. Owner unpause does **not** set `bridgeOpen` again.

## 4. Git merge ≠ live mint

`bridgeOpen` starts **false**. Owner opens only after peers, DVN, caps, and `listingTag` are on-chain. A patched repo that is not configured is still closed.

## 5. Per-tx and per-day caps

`maxPerTx` and `maxPerDay` (rolling 24h) are **per OApp**, not a protocol-wide cap. A source send of 100 and the dest mint of 100 each consume 100 on **that** contract. Set source and dest equal if you want the same bound on both legs. Required before `openBridge`.

## 6. Isolate listings

One inner token per contract. Payload is `(listingTag, to, amount)`. A message for hxSQUID cannot credit hcbETH. Pause one OApp; the others keep running.

## 7. Not LZ OFT shared-decimals

Wrap messages carry a full `uint256` amount. We do **not** use LayerZero OFT `sharedDecimals = 6`. Do not add that truncation — it would create the dust-arb this rule exists to avoid. Local rounding that *does* exist is protocol-favorable: redeem `_assetsForShares` floors; `notify` reverts `DustNotify` instead of trapping WHYPE.

## 8. Circuit breaker is Health, not an oracle

Guardian `setHealth(Degraded)` stops mint. `innerSupplyCeiling` + `reportInnerSupply` stops an upstream print. `maxPerTx` / `maxPerDay` / caps bound a dump. There is **no** EMA/price feed on the adapter — a feed would be a new mint authority. If the inner goes to zero, halt that listing; do not auto-pause from a USD oracle we do not have.

---

See also [`TRUST.md`](TRUST.md): authorization ≠ accounting ≠ solvency. `Health` + inner supply ceiling sit on top of these six rules.
