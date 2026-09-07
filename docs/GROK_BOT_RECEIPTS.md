# Grok bot — hgSOON + hsWBERA testnet

Copy-paste after you have read `docs/SOLVENCY.md` (hgSOON, hsWBERA) and `test/lz/LeafReceiptOnly.t.sol`. **Do not deploy mainnet.** **Do not set `INNER_TOKEN`.** Scripts revert if the inner is the live gSOON / sWBERA.

Branch: `feat/lz-oft-wrap`. Same four keys as `docs/GROK_BOT_TESTNET.md`. Skip `SetSecurityStack` on testnet.

Yield is **in the share rate**. No QUID poke. `pullYield(inner)` must revert `CannotPullInner`.

Never call on the inner (even on mock, do not add these to smoke):

| Listing | Forbidden |
| --- | --- |
| hgSOON | `cooldownShares` 0x9343d9e1, `cooldownAssets` 0xcdac52ed, `claim(address)` 0x1e83409a, `deposit` SOON |
| hsWBERA | ERC-4626 `withdraw` 0xb460af94, `redeem` 0xba087652, `queueWithdraw`/`queueRedeem`, `completeWithdrawal`, `deposit`/`depositNative` |

Users exit via HyperEVM/source market or **their own** official unbond after unwrap. The lockbox only `transfer`s the receipt.

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

`INNER.balanceOf(OWNER)` on 97 must rise. `pullYield($INNER)` from owner must revert.

---

## B. hsWBERA — Base Sepolia mock → 998

Bepolia (80069) LZ endpoint list is empty. Testnet source is **Base Sepolia mock sWBERA**, not live `0x118D…`. Mainnet source is Berachain 80094.

Same steps as hxSQUID, swap `ASSET=hswbera`. Peers: source `REMOTE_EID=40362`, dest `REMOTE_EID=40245`.

```
ASSET=hswbera OWNER=$OWNER GUARDIAN=$GUARDIAN FEE_RECIPIENT=$FEE_RECIPIENT \
forge script script/lz/DeployTestnetSource.s.sol:DeployTestnetSource \
  --rpc-url base_sepolia --broadcast --private-key $PRIVATE_KEY
```

Then dest / wire / configure / openPeg / smoke — identical to `docs/GROK_BOT_TESTNET.md` steps 2–6 with `ASSET=hswbera` and dest `REMOTE_EID=40245`.

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
