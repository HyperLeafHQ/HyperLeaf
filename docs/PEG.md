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

`maxPerTx` and `maxPerDay` (rolling 24h). One order cannot empty the reserve. Required before `openBridge`.

## 6. Isolate listings

One inner token per contract. Payload is `(listingTag, to, amount)`. A message for hxSQUID cannot credit hcbETH. Pause one OApp; the others keep running.

---

See also [`TRUST.md`](TRUST.md): authorization ≠ accounting ≠ solvency. `Health` + inner supply ceiling sit on top of these six rules.
