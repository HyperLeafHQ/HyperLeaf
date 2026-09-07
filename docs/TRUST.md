# Asset trust model

Liquid did not lose keys. It **treated an unbacked receipt as payable** and ran a normal peg-out. HyperLeaf is the same shape. So:

> Never trust an underlying merely because `balanceOf` increased.

Outstanding Leaf claims ≤ **verified economically realizable** claims — not token balances.

## Three checks, always separate

| Layer | Question | In code |
| ----- | -------- | ------- |
| **Authorization** | Who is allowed to say this happened? | peer, owner, guardian, harvester |
| **Accounting** | What number do we write? | `totalLocked`, tickets, yield, fees |
| **Solvency** | Can we actually pay? | cash check, `innerSupplyCeiling`, `Health` |

A valid LayerZero message is **not** economic truth. Peer authenticity ≠ backing.

`pokeClaim` is a **function template**: target + selector. Not “any calldata on an allowlisted contract.”

## Origin

Mint only from `send()` → `transferFrom` of the **immutable inner token**. Donations do not raise `totalLocked` and do not mint. Every payload carries `listingTag`. Trace:

```
hKAITO → totalLocked sKAITO in the lockbox → that ERC-20 → its issuer
```

If any link is unknown, do not mint.

Address-keyed externals (hORDER): CREATE2 same lockbox on Arb and Base is **identity**, not a shared balance. Solvency is the foreign ledger’s stake for that address (`ledgerPrincipal`), never `balanceOf(lockbox)` after the token has left.

## Health

| State | Mint | Redeem |
| ----- | ---- | ------ |
| Normal | yes | yes |
| Degraded | no | yes if cash (upstream suspect) |
| Halted | no | no |
| Insolvent | no | no (do not pay remaining real assets 1:1 against possibly fake claims) |

Anyone may `reportInnerSupply`. If `inner.totalSupply()` exceeds the ceiling, health becomes Degraded. Guardian can only worsen. Owner restores Degraded/Halted. Insolvent needs `recoverInsolvent`.

Stuck LZ: owner is the LZ delegate and calls `Endpoint.skip` on the OApp (we cannot wrap `skip` on the lockbox — IR stack). That does **not** return tokens. Then Halted/Insolvent + owner `abortCredit`. Convert-to-HYPE swap failures stay in the converter — turn `convertYieldToHype` off. Do not unpause to “retry” a skip.

1% fee is `y/100`. Sub-100 wei yield pays 0 fee (holders keep dust). `notify` reverts `DustNotify` if WHYPE would not move `accHypePerShare`, so 1 wei cannot jam the rewarder.

This is how HyperLeaf **stops amplifying** an upstream print. It cannot make a broken sKAITO real.

## Types

| Type | Example | Verified backing |
| ---- | ------- | ---------------- |
| A native ERC-20 | rare | lockbox pull of that token + supply ceiling |
| B staking receipt | xSQUID, sKAITO | receipt pulled + ceiling; yield is side token / HYPE, not a second mint |
| C vault share | cbETH, sETHFI | shares × issuer rate, still subject to ceiling and health |
| D locked position | BLUAI4Y, PTSMAX NFT | farm/NFT id we created, not a random transfer |
| E cross-chain claim | LZ hToken | source `totalLocked` **and** dest `supplyCap`; message tag |

## Attack we optimize for

```
upstream bug → fake inner → HyperLeaf send() → real hToken → normal redeem
```

Keys can be perfect. Pause mint first. Do not keep minting while you “look into it.”
