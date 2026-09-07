# Asset solvency (merge gate)

No listing goes to production until every field below has an answer. Config in `catalog.json` is not a solvency proof. L / C1 / C2 is **exit shape**. ERC-20 vs 4626 vs NFT vs merkle is **accounting**.

Peg identity, caps, and `balanceOf` cash checks are blast-radius tools. They do not make a forged inner token real. See [`TRUST.md`](TRUST.md).

| Asset | Canonical backing | Mint authority | Redeem authority | Yield | Accounting unit | Solvency proof | Failure mode | Pause trigger | Max loss |
| ----- | ----------------- | -------------- | ---------------- | ----- | --------------- | -------------- | ------------ | ------------- | -------- |
| **hNEST** | NEST in NestVault / HEV | NestVault.deposit | Nest/HEV windows | NEST compound + weekly HYPE | hNEST shares | vault assets ≥ shares (live, capped) | HEV mis-account | guardian pause | deposit cap |
| **hxSQUID** | xSQUID pulled into lockbox | `send` + LZ + tag | burn hToken + cash | QUID → HYPE | 1 lock = 1 hToken | `totalLocked` + inner supply ceiling + cash | Squid print / selector drift | ceiling or health | min(depositCap, maxPerDay) |
| **hcbETH** | cbETH pulled | same | same | rate in cbETH, no inner pull | 1 = 1 cbETH | Coinbase supply ceiling + cash | issuer / wrap bug | ceiling | same |
| **hKAITO** | sKAITO pulled (not KAITO) | same; omnichain holder for other-chain drops | sKAITO out, never official 7d unstake | eco ERC-20s → HYPE | 1 = 1 sKAITO | sKAITO ceiling; blacklist can brick redeem | Sign campaign / blacklist | health | same |
| **BLUAI4Y** | BLUAI in farm we staked | inbound lock + farm stake | market until `shareExit` | farm claim → HYPE | C1 ticker | NFT/farm id we created | farm upgrade | closeBridge | C1: no protocol BTC-style peg-out |
| **hVIRTUALMAX** | VIRTUAL in auto-max lock | inbound + Virtuals stake | market | launchpad ERC-20s | C1 | position we opened | airdrop spam / other chain | closeBridge | C1 |
| **PTSMAX** | River Pts → sRIVER_V2 NFT | convert then NFT lockbox | C1 / max-date | merkle Pts compound | NFT id | tokenId we minted, not balanceOf Pts | merkle key = EOA not NFT | do not ship on ERC20 adapter | C1 |
| **hSKY** | parked | — | — | — | — | LockStake borrow not stripped | — | — | not in prod |

**Global outflow.** Real inner leaving a lockbox is bounded by **that lockbox’s** `maxPerDay` on redeem (`_lzReceive` / `claim`), not the sum of source send + dest mint. Dest `maxPerDay` only bounds new hTokens. Set them equal so a wrap cannot mint faster than the source will later pay.

**Claim calls.** `pokeClaim` needs `setClaimCall(target, selector)`. Target-only allowlist cannot run arbitrary calldata.

A PR that cannot fill this table for a new ticker does not merge.
