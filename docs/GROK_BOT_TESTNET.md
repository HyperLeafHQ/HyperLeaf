# Grok bot — hxSQUID / hAVNT then hcbETH / BLUAI4Y testnet

**Do not deploy mainnet. Do not set `INNER_TOKEN`.** Scripts revert if you point at live xSQUID / cbETH / BLUAI, or if you broadcast on 8453/999/56.

`ASSET` this round is `hxsquid` | `havnt` | `hcbeth` | `bluai4y` (`TestnetCatalog`). Do not deploy NestVault, HNest, HevAdapter, LeafVirtualsLockbox, LeafOmnichainHolder, LeafCreate2.

hxSQUID and hAVNT share `pokeRewards` `0x9a99b4f0` (`claimRewards(this, max)`). Forbidden selector: Avantis `claimRewardsAndRedeem` **`0xeab52318`** (burns stkAVNT). Claim **tx** `0x26f4ca90`. Combined-redeem **tx** `0x24398d72` is the same function — its selector is `0xeab52318`, already blacklisted. Do not put a tx-hash prefix in `setRewardsSelector`. Then `pullYield` QUID or AVNT. C1: `pokeRewards` is farm `claimAll`. Do not `setShareExit`. Cross-chain board: dest `LeafReleased` is not done; wait source `Paid`.

Branch: `feat/lz-oft-wrap`. Faucets: Base Sepolia ETH, HyperEVM testnet HYPE ([testnet drip](https://app.hyperliquid-testnet.xyz)).

Keys: `OWNER`, `GUARDIAN`, `HARVESTER`, `CONVERTER` — four different EOAs. `PRIVATE_KEY` is OWNER.

```
cp env.testnet.example .env.testnet
# fill keys, then:
set -a && source .env.testnet && set +a
```

HyperEVM testnet LZ DVNs are Labs + P2P only. **Skip `SetSecurityStack`.**

---

## 1. Source — Base Sepolia (84532)

```
ASSET=hxsquid OWNER=$OWNER GUARDIAN=$GUARDIAN FEE_RECIPIENT=$FEE_RECIPIENT \
forge script script/lz/DeployTestnetSource.s.sol:DeployTestnetSource \
  --rpc-url base_sepolia --broadcast --private-key $PRIVATE_KEY
```

Copy logs:

- `MockInner` → `INNER`
- `MockSideToken` (hxSQUID = QUID, hAVNT = AVNT)
- `LeafOFTAdapter` → `SOURCE`

Same command with `ASSET=havnt` (same chain, same selector). hcbETH: `ASSET=hcbeth` (no side token).

## 2. Dest — HyperEVM 998

```
ASSET=hxsquid OWNER=$OWNER GUARDIAN=$GUARDIAN \
forge script script/lz/DeployTestnetDest.s.sol:DeployTestnetDest \
  --rpc-url hyperevm_testnet --broadcast --private-key $PRIVATE_KEY
```

Copy: `LeafOFT` → `OFT`. Do **not** deploy a wrap registry.

## 3. Peers both ways

```
OAPP=$SOURCE PEER=$OFT REMOTE_EID=40362 \
forge script script/lz/WirePeers.s.sol:WirePeers \
  --rpc-url base_sepolia --broadcast --private-key $PRIVATE_KEY

OAPP=$OFT PEER=$SOURCE REMOTE_EID=40245 \
forge script script/lz/WirePeers.s.sol:WirePeers \
  --rpc-url hyperevm_testnet --broadcast --private-key $PRIVATE_KEY
```

## 4. Harvest roles (source)

```
ASSET=hxsquid SOURCE=$SOURCE OWNER=$OWNER HARVESTER=$HARVESTER CONVERTER=$CONVERTER \
forge script script/lz/ConfigureTestnetListing.s.sol:ConfigureTestnetListing \
  --rpc-url base_sepolia --broadcast --private-key $PRIVATE_KEY
```

Sets `convertYieldToHype`, harvester (still used as converter keeper), converter. **CONVERTER must be `LeafYieldConverter`, not an EOA.** Deploy with `DeployYieldConverter.s.sol` first, then allowlist lockbox / QUID / routes (include deBridge + Mayan as backups). hxSQUID also sets `rewardsSelector` `0x9a99b4f0`.
hcbETH: script also `setRateKind(ExchangeRate)` + `setRetainRateYield(true)`. Mock inner is `MockRateERC20` with `exchangeRate()`. To smoke harvest: `cast send $INNER "setRate(uint256)" 1100000000000000000` then anyone `pullYield(inner, converter)` — converter receives **1% of surplus**, ~99.91% stays in the lockbox. Wrap itself must **not** move surplus. Donation is not yield. Redeem remaining cbETH, not 1:1 after the skim. No holder WHYPE claim on this ticker.


## 4c. Rewarder bind (HyperEVM 998) — order is the test

```
OFT.setHypeRewarder(REWARDER, listingId)   # listingId one-shot; do this first
REWARDER.register(listingId, OFT)          # reverts ListingMismatch if reversed
```

`listingId` must be the catalog id for that ticker, not another listing’s.
Do not `register` before `setHypeRewarder`. Dust: `minNotify(listingId)` on
the rewarder; `notify` below that reverts `DustNotify` and WHYPE stays with
the keeper. Transfer of the OFT must still succeed if you point
`setHypeRewarder` at a broken contract (`RewardsHookFailed`).



## 4b. Peg (both sides) — required before smoke

```
ASSET=hxsquid OAPP=$SOURCE \
forge script script/lz/OpenPeg.s.sol:OpenPeg \
  --rpc-url base_sepolia --broadcast --private-key $PRIVATE_KEY

ASSET=hxsquid OAPP=$OFT \
forge script script/lz/OpenPeg.s.sol:OpenPeg \
  --rpc-url hyperevm_testnet --broadcast --private-key $PRIVATE_KEY
```

Read `listingTag`, `maxPerTx`, peers on-chain. Source also needs `INNER_SUPPLY_CEILING` (above mock totalSupply). Then rerun with `OPEN_BRIDGE=true`. Mint is closed until that flag.

## 5. Smoke deposit (Base → 998)

```
SOURCE=$SOURCE INNER=$INNER OWNER=$OWNER TO=$OWNER AMOUNT=50000000000000000 \
forge script script/lz/SmokeTestnetSend.s.sol:SmokeTestnetSend \
  --rpc-url base_sepolia --broadcast --private-key $PRIVATE_KEY
```

Wait for LZ. Then `OFT.balanceOf(OWNER)` on 998 should be 0.05.

## 6. Smoke redeem (998 → Base) — L only

```
OFT=$OFT OWNER=$OWNER TO=$OWNER AMOUNT=50000000000000000 \
forge script script/lz/SmokeTestnetRedeem.s.sol:SmokeTestnetRedeem \
  --rpc-url hyperevm_testnet --broadcast --private-key $PRIVATE_KEY
```

Wait. `INNER.balanceOf(OWNER)` on Base should rise.

hcbETH after a rate harvest: inner returned is **remaining**, not the minted amount. Do not assert 1:1.

C1 (`bluai4y`) dest is `LeafClosedOFT`. After deploy check `redeemEnabled == false`. Do not `setRedeemEnabled(true)` this round. Step 6 **must revert** `ExitViaMarketOnly`. Do bluai4y only after both L paths pass.

---

## Pass / fail

| Check | hxsquid | hcbeth | bluai4y |
| --- | --- | --- | --- |
| Deposit mints dest ticker | yes | yes | yes |
| Burn dest returns inner | 1:1 xSQUID | remaining cbETH (not 1:1 after harvest) | **no** (`redeemEnabled` false) |
| `pullYield(inner)` | revert `CannotPullInner` | **1% of** rate surplus; 99% stays | surplus BLUAI ok |
| pokeRewards on mock xSQUID | mints 1 mock QUID to lockbox | n/a | n/a |

Log every address in the PR. Tiny caps. Then repeat 1–6 with `ASSET=hcbeth`.

---

## 7. Attack simulation (after both L smokes)

Not “did mint work”. Each listing: hxSQUID, hcbETH, then BLUAI4Y. After a **normal** deposit → LZ → mint → transfer (L: redeem), inject:

```
wrong listingTag
wrong peer
bridge closed (guardian)
tx > maxPerTx
day > maxPerDay
supply cap
cash insufficient (burn lockbox tokens)
innerSupplyCeiling breach
wrong claim selector
zero-supply harvest
```

Each must: explicit revert, no partial state, **other listing untouched**.

Then answer only:

1. Worst-case loss (should be `maxPerTx` / remaining cap, not unbounded)
2. Can guardian halt in time (`closeBridge` / `setHealth`)
3. Does the broken listing contaminate another (`listingTag` / separate lockbox)

Do **not** add more assets until this page has those three answers logged in the PR.

---

## 8. Claim board (C1 / hNEST) — after wrap smoke

LZ fee on fill/abort is LayerZero’s, not ours. Abort handshake must exist before this deploy.

Dest (998), after OFT + optional Rewarder:

```
LEAF=$OFT WANT=$INNER OWNER=$OWNER GUARDIAN=$GUARDIAN REWARDER=$REWARDER \
forge script script/lz/DeployClaimDest.s.sol:DeployClaimDest \
  --rpc-url hyperevm_testnet --broadcast --private-key $PRIVATE_KEY
```

Source (same chain as wrap source):

```
WANT=$INNER OWNER=$OWNER GUARDIAN=$GUARDIAN RETURN_NATIVE=10000000000000000 \
forge script script/lz/DeployClaimSource.s.sol:DeployClaimSource \
  --rpc-url base_sepolia --broadcast --private-key $PRIVATE_KEY
```

Wire both ways (`OAPP`/`PEER` = escrow ↔ fill). `WirePeers` `setPeer(address)` matches.

hNEST: dest-only, `fillLocal`, no Fill contract.

If ACK is lost: `escrow.retryAck{value}(id)`. Guardian may `abortFill` without waiting 3 days. Buyer waits `ABORT_DELAY`. Stuck FILL nonce: owner `Endpoint.skip` (delegate), then `retryRefund` / `abortFill`.

Smoke: list 100 Leaf / ask 70 inner → fill → dest Leaf to buyer, source 69.3 to seller, 0.7 to buyer. `totalLocked` unchanged.

## Still not this pass

- Mainnet inners, `SetSecurityStack`, WHYPE converter fills, multi-DEX/bridge converter routes
- hKAITO / hVIRTUALMAX / hSKY / hsWBERA (not this `ASSET` round)
- NestVault / HNest / HevAdapter
- LeafVirtualsLockbox / LeafOmnichainHolder / LeafCreate2
- C1 `shareExit` / protocol redeem
- generic `pokeClaim` / `harvestToken` (removed from wrap lockboxes)

---

## Next testnet batch — hgSOON / hsAVAX / hstkwaUSDC / hsETHFI (do not mix with §7 of this round)

`TestnetCatalog.get` still reverts for these ids. Use `ASSET=hgsoon|hsavax|hstkwausdc|hsethfi` — scripts go through `TestnetListings` → `NextTestnetCatalog`. Round-1 four ids stay locked.

| ASSET | Source testnet | Mock | Configure |
| --- | --- | --- | --- |
| `hgsoon` | BSC 97 (eid 40102) | `convertToAssets` | ConvertToAssets + retain. No rewards selector |
| `hsavax` | Fuji 43113 (eid 40106) | `getPooledAvaxByShares` | GetPooledAvaxByShares + retain. No rewards selector |
| `hstkwausdc` | Sepolia 11155111 (eid 40161) | `convertToAssets` + MockRewardsController | ConvertToAssets + retain + `REWARDS_CONTROLLER` + selector `0xbb492bf5` |
| `hsethfi` | Sepolia 11155111 (eid 40161) | plain ERC-20 | **No** rateKind. **No** rewardsSelector. Wrap sETHFI 1:1 |

Copy-paste: `docs/GROK_BOT_RECEIPTS.md`. Do **not** point `INNER_TOKEN` at mainnet. Do **not** add these to `TestnetCatalog`.

`claimAllRewards` is **on the controller**, never on the StakeToken. `cooldown` / `requestUnlock` / ether.fi `requestWithdraw` / teller `deposit` stay blacklisted. Unwrap is the receipt (gSOON / sAVAX / stk v1 / sETHFI). Protocol never starts Aave cooldown, BENQI unlock, or the 10d DelayedWithdraw.

