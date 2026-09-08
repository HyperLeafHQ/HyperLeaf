# Grok bot — next-batch L receipts (hgSOON / hsAVAX / hstkwaUSDC)

Copy-paste after `docs/SOLVENCY.md` and `test/lz/LeafRateYield.t.sol` / `test/lz/LeafUmbrella.t.sol`. **Do not deploy mainnet.** **Do not set `INNER_TOKEN`.** Scripts revert if the inner is the live token.

Round-1 `TestnetCatalog.get` still reverts for these ids. `ASSET=…` goes through `TestnetListings` → `NextTestnetCatalog`.

Source testnet is the **same family as mainnet**. Do not put Fuji/Sepolia/BSC assets on Base Sepolia.

| ASSET | Mainnet source | Testnet source | Dest |
| --- | --- | --- | --- |
| `hgsoon` | BSC 56 | **BSC testnet 97** (LZ eid 40102) | HyperEVM 998 |
| `hsavax` | Avalanche 43114 | **Fuji 43113** (eid 40106) | HyperEVM 998 |
| `hstkwausdc` | Ethereum 1 | **Sepolia 11155111** (eid 40161) | HyperEVM 998 |

Skip `SetSecurityStack` on testnet. Same four keys as `docs/GROK_BOT_TESTNET.md`.

Rate listings: `retainRateYield`. Wrap/redeem settle the 1% first. `pullYield(inner, converter)` after `setRate` on the mock — converter gets **1% of surplus**. Donation is not yield. Never call vault unbond / cooldown / `requestUnlock` on the inner.

---

## A. hgSOON — BSC testnet 97 → HyperEVM 998

```
ASSET=hgsoon OWNER=$OWNER GUARDIAN=$GUARDIAN FEE_RECIPIENT=$FEE_RECIPIENT \
forge script script/lz/DeployTestnetSource.s.sol:DeployTestnetSource \
  --rpc-url bsc_testnet --broadcast --private-key $PRIVATE_KEY
```

Log `MockInner` → `INNER`, `LeafOFTAdapter` → `SOURCE`.

```
ASSET=hgsoon OWNER=$OWNER GUARDIAN=$GUARDIAN \
forge script script/lz/DeployTestnetDest.s.sol:DeployTestnetDest \
  --rpc-url hyperevm_testnet --broadcast --private-key $PRIVATE_KEY
```

Log `LeafOFT` → `OFT`.

```
OAPP=$SOURCE PEER=$OFT REMOTE_EID=40362 \
forge script script/lz/WirePeers.s.sol:WirePeers \
  --rpc-url bsc_testnet --broadcast --private-key $PRIVATE_KEY

OAPP=$OFT PEER=$SOURCE REMOTE_EID=40102 \
forge script script/lz/WirePeers.s.sol:WirePeers \
  --rpc-url hyperevm_testnet --broadcast --private-key $PRIVATE_KEY
```

```
ASSET=hgsoon SOURCE=$SOURCE OWNER=$OWNER HARVESTER=$HARVESTER CONVERTER=$CONVERTER \
forge script script/lz/ConfigureTestnetListing.s.sol:ConfigureTestnetListing \
  --rpc-url bsc_testnet --broadcast --private-key $PRIVATE_KEY
```

```
ASSET=hgsoon OAPP=$SOURCE INNER_SUPPLY_CEILING=2000000000000000000000000 \
forge script script/lz/OpenPeg.s.sol:OpenPeg \
  --rpc-url bsc_testnet --broadcast --private-key $PRIVATE_KEY

ASSET=hgsoon OAPP=$OFT \
forge script script/lz/OpenPeg.s.sol:OpenPeg \
  --rpc-url hyperevm_testnet --broadcast --private-key $PRIVATE_KEY
```

Read `listingTag`, peers, caps on-chain. Then:

```
OPEN_BRIDGE=true ASSET=hgsoon OAPP=$SOURCE INNER_SUPPLY_CEILING=2000000000000000000000000 \
forge script script/lz/OpenPeg.s.sol:OpenPeg \
  --rpc-url bsc_testnet --broadcast --private-key $PRIVATE_KEY

OPEN_BRIDGE=true ASSET=hgsoon OAPP=$OFT \
forge script script/lz/OpenPeg.s.sol:OpenPeg \
  --rpc-url hyperevm_testnet --broadcast --private-key $PRIVATE_KEY
```

Smoke 0.05:

```
SOURCE=$SOURCE INNER=$INNER OWNER=$OWNER TO=$OWNER AMOUNT=50000000000000000 \
forge script script/lz/SmokeTestnetSend.s.sol:SmokeTestnetSend \
  --rpc-url bsc_testnet --broadcast --private-key $PRIVATE_KEY
```

Wait LZ. `OFT.balanceOf(OWNER)` on 998 = 0.05. Then redeem:

```
OFT=$OFT OWNER=$OWNER TO=$OWNER AMOUNT=50000000000000000 \
forge script script/lz/SmokeTestnetRedeem.s.sol:SmokeTestnetRedeem \
  --rpc-url hyperevm_testnet --broadcast --private-key $PRIVATE_KEY
```

`INNER.balanceOf(OWNER)` on 97 must rise.

Harvest smoke: `cast send $INNER "setRate(uint256)" 1100000000000000000` then anyone `pullYield($INNER, $CONVERTER)` — converter receives **1% of surplus**. `pullYield` of the inner is the skim, not a bug. Cooldown selectors must revert if set.

---

## B. hsAVAX — Fuji 43113 → HyperEVM 998

Same scripts, `ASSET=hsavax`. Mock is `getPooledAvaxByShares`. **No** `setRewardsSelector`. Never `requestUnlock`.

```
ASSET=hsavax OWNER=$OWNER GUARDIAN=$GUARDIAN FEE_RECIPIENT=$FEE_RECIPIENT \
forge script script/lz/DeployTestnetSource.s.sol:DeployTestnetSource \
  --rpc-url fuji --broadcast --private-key $PRIVATE_KEY
```

Dest 998 `ASSET=hsavax`. Wire source `REMOTE_EID=40362`, dest `REMOTE_EID=40106`.

```
ASSET=hsavax SOURCE=$SOURCE OWNER=$OWNER HARVESTER=$HARVESTER CONVERTER=$CONVERTER \
forge script script/lz/ConfigureTestnetListing.s.sol:ConfigureTestnetListing \
  --rpc-url fuji --broadcast --private-key $PRIVATE_KEY
```

Harvest: `cast send $INNER "setRate(uint256)" 1100000000000000000` then `pullYield`. Unwrap returns sAVAX mock, not AVAX.

---

## C. hstkwaUSDC — Sepolia 11155111 → HyperEVM 998

Dual harvest. Log `MockRewardsController` from deploy → `REWARDS_CONTROLLER`.

```
ASSET=hstkwausdc OWNER=$OWNER GUARDIAN=$GUARDIAN FEE_RECIPIENT=$FEE_RECIPIENT \
forge script script/lz/DeployTestnetSource.s.sol:DeployTestnetSource \
  --rpc-url sepolia --broadcast --private-key $PRIVATE_KEY
```

Dest 998 `ASSET=hstkwausdc`. Wire dest `REMOTE_EID=40161`.

```
ASSET=hstkwausdc SOURCE=$SOURCE OWNER=$OWNER HARVESTER=$HARVESTER CONVERTER=$CONVERTER \
REWARDS_CONTROLLER=$REWARDS_CONTROLLER \
forge script script/lz/ConfigureTestnetListing.s.sol:ConfigureTestnetListing \
  --rpc-url sepolia --broadcast --private-key $PRIVATE_KEY
```

Rate smoke: same `setRate` + `pullYield(inner)` 1%. Side-token smoke: seed the mock controller for the lockbox, `pokeRewards` — GHO lands in lockbox, stk balance unchanged, then `pullYield(gho, converter)`. Never `cooldown` on the mock inner.

---

## D. hsWBERA — Bepolia 80069 → 998 (blocked)

Do not run until `eth_getCode` of the Bepolia EndpointV2 is non-empty. Then add `ENDPOINT_BEPOLIA` to `LayerZeroAddresses` and:

```
ASSET=hswbera OWNER=$OWNER GUARDIAN=$GUARDIAN FEE_RECIPIENT=$FEE_RECIPIENT \
forge script script/lz/DeployTestnetSource.s.sol:DeployTestnetSource \
  --rpc-url https://bepolia.rpc.berachain.com --broadcast --private-key $PRIVATE_KEY
```

Dest / wire: source `REMOTE_EID=40362`, dest `REMOTE_EID=40371`. Mock inner only — never live `0x118D…`.

Until that ships: `forge test --match-contract LeafReceiptOnlyTest`.

---

## Failures to inject (each listing, after happy path)

wrong listingTag · wrong peer · guardian `closeBridge` · tx > maxPerTx · day cap · supply cap · cash insufficient · innerSupplyCeiling · `pullYield(inner)`.

Each: revert, no partial state, other listing untouched.

Log every address in the PR.

---

## Mainnet (do not run unless owner says so)

`ASSET=hgsoon` on chain **56**, `ASSET=hswbera` on **80094**:

```
ASSET=hgsoon OWNER=… GUARDIAN=… FEE_RECIPIENT=… \
forge script script/lz/DeployAdapter.s.sol:DeployAdapter --rpc-url <bsc> --broadcast

ASSET=hgsoon OWNER=… GUARDIAN=… \
forge script script/lz/DeployOFT.s.sol:DeployOFT --rpc-url <hyperevm> --broadcast
```

Wire `REMOTE_EID=30367` from source, `30102` (gSOON) or `30362` (sWBERA) from HyperEVM.

`SetSecurityStack`: HyperEVM `ASSET=hgsoon` (remote BSC). On BSC/Bera set `DVN0,DVN1,DVN2` from the LZ chain page (Labs + Horizen + Nethermind). `OPEN_BRIDGE=true` only after reading live tag/peers/caps. Do not call any forbidden selector on the inner.
