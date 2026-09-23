# Grok bot — Leaf Market (HyperEVM mainnet)

You deploy. You do **not** rename the product, restyle the frontend, deploy
NestVault / Gate / LeafClaimFill, or open a cross-chain peer because a PR
merged. Branch: `feat/lz-oft-wrap`. Log every address on the PR.

Product name: **Leaf Market**. ZH: **Leaf 市场**. Never “Claim Market”,
never show `LeafClaimEscrow` in UI copy.

Frontend copy is a **different** bot: [`GROK_BOT_FRONTEND.md`](GROK_BOT_FRONTEND.md).
This job is **not** BATCH 0–5. Do not wait for bluai4y / horder wrap smoke.

---

## This job (one chain)

HyperEVM **999** only. Same-chain `fillLocal` for **hNEST ↔ NEST**.

| Role | Address |
| --- | --- |
| NestVault (do **not** touch) | `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` |
| hNEST (`LEAF`) | `0x2101621F51D7E05518D6680C62d04Ad47bC4e05D` |
| NEST (`WANT`) | `0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035` |
| LZ Endpoint (ctor only) | `0x3A73033C0b1407574C76BdBAc67f126f6b4a9AA9` |
| Owner | `0x24458f0bC44C4607172d1151Cd938012Be33156e` |
| Guardian | `0x12dF4528E7Cc3db07A509c966c6405b69A25Ef2e` |
| feeRecipient | `0x76c8c4586F0a3d335CF7192eBbB4FE6Ed5Af3804` |

`OWNER` ≠ `GUARDIAN` ≠ `FEE_RECIPIENT`. `PRIVATE_KEY` is OWNER. Do not leave
this bot as owner.

---

## Do

```
OWNER=0x24458f0bC44C4607172d1151Cd938012Be33156e \
GUARDIAN=0x12dF4528E7Cc3db07A509c966c6405b69A25Ef2e \
FEE_RECIPIENT=0x76c8c4586F0a3d335CF7192eBbB4FE6Ed5Af3804 \
LEAF=0x2101621F51D7E05518D6680C62d04Ad47bC4e05D \
WANT=0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035 \
forge script script/lz/DeployClaimDest.s.sol:DeployClaimDest \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
```

Then verify, **before** any UI:

1. `chainid == 999`
2. `escrow.owner()` = Owner (Ownable2Step: `transferOwnership` → Owner `acceptOwnership` if the script left you as owner)
3. `escrow.guardian()` = Guardian
4. `escrow.feeRecipient()` = feeRecipient
5. `markets(hNEST, NEST).allowed == true`
6. `markets(hNEST, NEST).rewardId == 0`
7. `rewarder() == address(0)`
8. `remoteEid() == 0` and `peers(*)` empty — **do not `setPeer`**
9. `configFrozen` may stay false (freeze requires a peer; we do not add one)

Smoke on dust (your own hNEST + NEST, not user funds):

- `list` dust hNEST, ask in NEST, TTL ≤ 90d
- other EOA `fillLocal` → buyer gets exact leaf, seller 99% NEST, buyer 1% NEST
- `hNEST.totalSupply()` unchanged
- NestVault `totalNestLocked` unchanged
- seller `cancel` returns Leaf, no fee
- seller cannot `fillLocal` own order
- expired order: `expire` returns Leaf

PR comment after smoke:

1. Worst-case: one listed amount, in escrow, cancellable. Not unbounded.
2. Guardian `pause()` blocks new `list` / `fillLocal`. Owner unpauses.
3. This listing cannot mint hNEST or touch NestVault.

---

## Do not

- Deploy `LeafClaimFill` / `DeployClaimSource`
- `setPeer` / `WirePeers` / `SetSecurityStack` / `OPEN_BRIDGE`
- `setRewarder` or any non-zero `REWARD_ID` (hNEST has no Rewarder)
- `setMarket` for any ticker except hNEST/NEST this job
- Touch NestVault, HNest, HevAdapter, live `0x4f6615…`. Gate redeploy is a **different** job: [`GROK_BOT_GATE.md`](GROK_BOT_GATE.md).
- Advertise weekly HYPE, occupancy HYPE, or “hNEST is always 8-day locked”
- Protocol bid / treasury fill / AMM
- Wait for BATCH 4
- Enable `requestWithdraw` in the UI
- Rename the product in the frontend (frontend bot owns copy)

---

## Copy the frontend bot must keep

Safe: “HyperLeaf's Leaf Market listing for hNEST.”
Not safe: “hNEST itself is always gated / 8-day locked.”
Not safe: “挂单期间 HYPE 归协议” (hNEST has no Rewarder).
Not safe: dest `Filled` on a future LZ path = 成交. This job is `fillLocal` only; `Filled` = done.

1% of ask → buyer incentive, not protocol fee. Protocol never bids. No fill, no trade.

---

## BLUAI4Y remote (live — do not redeploy)

`LeafClaimPeer` **must** have `receive()` + `rescueNative`. v1 Fill died: dest ACK refunds to `address(this)` with no `receive`. Live v2 (uncapped) already has it on-chain; this repo must match before the next (hORDER) deploy.

| | Address |
| --- | --- |
| Escrow HEVM | `0x367FB8667919dD94874C0a48156C94E0D254d43c` |
| Fill BSC | `0xE3E4B14d1c3d06297eca4d9B61b3dFa4d37e3b80` |

Dead 100-cap escrow/fill `0x1AD2…` / `0xC584…` — do not reuse. Abandoned Fill v1 `0x5466…` unused.

`remoteEid` is singular. Adding Arb to the BLUAI escrow reverts `PeerFrozen`. hORDER gets a **new** escrow + Arb fill.

## hORDER (LIVE — do not redeploy)

Escrow `0x4f4222546D1B4431A99A197a991E568Ee6C27A2F` (999). Fill `0x615487eD17D275390565E3880E3406093Ce81346` (42161 only; the same hex on Ethereum 1 is hLBTCv SOURCE). Owner FINAL. Do not reuse `0x367FB8…` / `0xE3E4B1…`.

`RETURN_NATIVE` (default 0.01 ETH) is the destination native drop so ACK can be sent. It is **not** the user's fee. UI calls `quoteFill` and pays that quote. Do not hardcode `fill{value: 0.01 ether}`.

`Paid` on Arb is the fill. Dest `LeafReleased` is not. 1% of ask is the buyer incentive, not protocol revenue. `ledgerPrincipal` risk is unchanged.
