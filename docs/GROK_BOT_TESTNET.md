# Grok bot — hxSQUID then hcbETH testnet

**Do not deploy mainnet. Do not set `INNER_TOKEN`.** Scripts revert if you point at live xSQUID / cbETH / BLUAI, or if you broadcast on 8453/999/56.

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
- `MockQUID` (hxSQUID only)
- `LeafOFTAdapter` → `SOURCE`

hcbETH later: same command with `ASSET=hcbeth` (no MockQUID).

## 2. Dest — HyperEVM 998

```
ASSET=hxsquid OWNER=$OWNER GUARDIAN=$GUARDIAN \
forge script script/lz/DeployTestnetDest.s.sol:DeployTestnetDest \
  --rpc-url hyperevm_testnet --broadcast --private-key $PRIVATE_KEY
```

Copy: `LeafOFT` → `OFT`. First run also logs `LeafWrapRegistry`.

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

Sets `convertYieldToHype`, harvester, converter. hxSQUID also sets `rewardsSelector` `0x9a99b4f0`.
hcbETH: script also `setRateKind(ExchangeRate)`. Mock inner is `MockRateERC20` with `exchangeRate()`. To smoke harvest: `cast send $INNER "setRate(uint256)" 1100000000000000000` then `pullYield(inner, converter)` — only surplus leaves.

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

C1 (`bluai4y`) step 6 **must revert** `ExitViaMarketOnly`. Do bluai4y only after both L paths pass.

---

## Pass / fail

| Check | hxsquid | hcbeth | bluai4y |
| --- | --- | --- | --- |
| Deposit mints dest ticker | yes | yes | yes |
| Burn dest returns inner | 1:1 xSQUID | remaining cbETH (not 1:1 after harvest) | **no** |
| `pullYield(inner)` | revert `CannotPullInner` | rate surplus only | surplus BLUAI ok |
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

## Still not this pass

- Mainnet inners, `SetSecurityStack`, WHYPE converter fills
- hKAITO / hVIRTUALMAX / hSKY
- NestVault v2
- hgSOON / hsWBERA testnet: **`docs/GROK_BOT_RECEIPTS.md`** (same scripts, different source RPC)
