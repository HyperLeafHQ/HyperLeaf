# HIP-4 call ladder (read only)

Approximate one vanilla call with the binaries already listed on HyperCore.

A `template:binaryPrice` YES coin pays 1 quote token if the settlement print is above its strike. Inside a ladder of those strikes, the call `max(S-K, 0)` sits between two packages:

- Superreplication buys `width` YES at the low end of each bucket. It pays the whole next bucket as soon as price crosses that strike.
- Subreplication buys `width` YES at the high end. It pays the bucket only after price clears it.
- The trapezoid mid is their average, and only when every leg has both a bid and an ask.

The linear piece above the highest strike is not priced. Nothing here signs, deploys, or sends an order. Portfolio margin is not treated as netting this package against a perp.

```
python3 research/hip4-vanilla/test_replicate.py
python3 research/hip4-vanilla/live.py BTC
```

`live.py` reads `outcomeMeta` and `l2Book` from `https://api.hyperliquid.xyz/info`. A missing bid or ask stays missing. A crossed book is dropped.
