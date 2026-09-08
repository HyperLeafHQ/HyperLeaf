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

Wrap lockboxes do not take arbitrary `pokeClaim` calldata. L uses a pinned `rewardsSelector` (Squid redeem 4-bytes denied). C1 uses `farmClaimSel` only.

## Origin

Mint only from `send()` → `transferFrom` of the **immutable inner token**. Donations do not raise `totalLocked` and do not mint. Every payload carries `listingTag`. Trace:

```
hKAITO → totalLocked sKAITO in the lockbox → that ERC-20 → its issuer
```

If any link is unknown, do not mint.

## Claim board vs mint ledger

The wrap path is the only mint. `LeafClaimEscrow` / `LeafClaimFill` **must not**
raise `totalLocked`, dest `totalSupply`, or tickets.

```
list   = ERC20 transfer of already-minted Leaf into escrow
fill   = inner moves seller ← buyer; Leaf moves escrow → buyer
cancel = Leaf back to seller
```

Fill is a wrap *redirect*, not a wrap. Inner paid on fill **never** enters the
lockbox. A 70 BLUAI fill against 100 Leaf does not mean 70 new backing.

Tests: `testFillDoesNotTouchLockbox`, `testFillLocalBuyerRewardNoMint`,
`testLzWrongAskRefunds`. If a fill mints or bumps `totalLocked`, the board is
broken — pause it, do not “fix” by minting the other side.


Address-keyed externals (hORDER): Orderly’s ledger keys by **EVM address**, chain-agnostic. HyperLeaf’s Arb lockbox is that address. Solvency is `ledgerPrincipal` for it, never `ORDER.balanceOf(lockbox)` after stake. CREATE2 twins would only be needed to be the *same* address on a second chain — **not deployed**. LZ wrap is a different idea (custody a token here, mint a receipt there). Do not open a Base/OP source into the same dest OFT (double-count).

## Health

| State | Mint | Redeem |
| ----- | ---- | ------ |
| Normal | yes | yes |
| Degraded | no | yes if cash (upstream suspect) |
| Halted | no | no |
| Insolvent | no | no (do not pay remaining real assets 1:1 against possibly fake claims) |

Anyone may `reportInnerSupply`. Only the listing's canonical inner counts. If `inner.totalSupply()` exceeds the ceiling, health becomes Degraded. Guardian can only worsen. Owner restores Degraded/Halted; `restoreHealth(Normal)` re-checks the ceiling (and hORDER `ledgerPrincipal`). Insolvent needs `recoverInsolvent`.

Stuck LZ: owner is the LZ delegate and calls `Endpoint.skip` on the OApp (we cannot wrap `skip` on the lockbox — IR stack). That does **not** return tokens. Then Halted/Insolvent + owner `abortCredit`. Convert-to-HYPE hop failure stays in `LeafYieldConverter` — `halt([lockbox])` so `pullYield` stops, then try deBridge/Mayan or `returnToLockbox`. Do not unpause wrap to “retry” a skip.


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

## Production keys (split; do not delete the functions)

Luna: operational security is the weak score, not “delete owner.” Owner is a **multisig**, not a hot wallet. Four roles, four keys. Constructor already rejects keeper == owner on the converter.

| Role | Holds | Can | Cannot |
| ---- | ----- | --- | ------ |
| **Owner** (multisig) | LZ delegate, restore, unpause, **lower** caps, DVN config while closed, `abortCredit`, rotate harvester/converter | Resume after halt. Rotate a burned keeper. Skip a stuck LZ nonce. | Replace an existing peer (ever). Raise caps. Change rate/retain after first deposit. Replace a live Rewarder while supply > 0. `pullYield`. `setEndpointConfig` while the bridge is live. Worsen health (guardian). |
| **Guardian** | pause, `closeBridge`, `setHealth` worse, `reportLedgerPrincipal` | Halt mint in minutes | Unpause, restore Normal, skip LZ, pull yield, change peers |
| **Harvester / keeper** | converter `execute` / `notify` / `returnToLockbox` | Move surplus that is already yield | Point `pullYield` `to` anywhere but the converter. Change peers. Unpause. **Must not** `notify` a different listing than the WHYPE came from (ops; not an on-chain bucket) |
| **Converter** | the contract, never an EOA | Hold inventory, minOut hops, halt pulls | Receive principal. Be the owner |

Do **not** remove: `abortCredit`, `setEndpointConfig`, `restoreHealth`, `farmUnstake`, `setRedeemEnabled`. Those are incident tools. Bind them to the multisig. `restoreHealth(Normal)` already re-checks the ceiling and hORDER `ledgerPrincipal` — it is not a bare declaration.

Do **not** put owner, guardian, harvester on one EOA. Scripts already revert `split keys`.

## Harvest attribution

`pullYield` is permissionless, destination-locked to the configured converter.

| What sits on the lockbox | Harvestable? | Backing? |
| --- | --- | --- |
| Inner, `RateKind.None` (hxSQUID / stkAVNT) | never (`CannotPullInner`) | yes, including donations |
| Inner, rate-bearing (cbETH, gSOON, jitoSOL) | only rate-implied surplus on `lastAccounted` | inner donations stay backing |
| Inner, C1 ORDER (`AmountNative`) | never — whole box balance is reserved | yes (idle ORDER is in-transit principal) |
| Inner, C1 BLUAI surplus over reserved | yes (farm rewards paid in inner) | reserved = `totalLocked`, or 0 while farmed |
| Any other ERC20 (QUID, AVNT, bribes, airdrops) | yes, entire balance | no. Pulling it does not change `totalLocked` / `lastAccounted` |

Unknown ERC20 is **airdrop capture**, not a second principal. That is why there is no yield-token allowlist. A donation of inner is the opposite: it stays with remaining holders.

`notify(id)` and `execute(..., tokenOut=0)` stay `onlyKeeper`. WHYPE in the converter is not tagged per listing, and bridge calldata can name any recipient. A compromised keeper can mis-attribute or redirect inventory. That is not a lockbox drain. Do not make those two calls permissionless until per-listing buckets and a bridge-destination bind exist.

Mainnet ULN is optional 2-of-3: LayerZero Labs + Horizen + Canary. Nethermind left the DVN role 2026-08-19 — do not put it back. Google Cloud is on Base but not HyperEVM, so it is not in the trio. Confirmations are per-pathway, not one number per chain: Send ULN on A uses A's depth; Receive ULN on B for messages from A must use the same A-depth. Base→HyperEVM is 15 on both Base send and HyperEVM receive. HyperEVM→Base is 5 on both HyperEVM send and Base receive. Depths: Base/OP/Arb/BSC/Bera/ETH 15, HyperEVM 5, Avax 12, Solana 32.

