# Grok bot — mainnet canary then real listings

**Go-live is mainnet.** HyperEVM testnet cannot run Labs + Horizen + Canary or the real confirmation split. Do not treat Base Sepolia / 998 as the wrap acceptance path.

Do **not** point any script at live xSQUID / stkAVNT / cbETH / gSOON / sWBERA until the canary has deposited, minted, and redeemed on **8453 ↔ 999**. Canary contracts are throwaway. Real listings are new addresses.

Keys: `OWNER`, `GUARDIAN`, `HARVESTER` — three EOAs. `PRIVATE_KEY` is OWNER. Converter is a contract (`LeafYieldConverter`), not an EOA.

`BATCH` is required on real deploys (`DeployAdapter` / `DeployOFT` / `ConfigureMainnetListing`). Default `BATCH=1`. Wrong ticker reverts `NotThisBatch`.

| BATCH | Tickers | Framework | Source |
| --- | --- | --- | --- |
| 0 | `hcanary` | Toy ERC-20, L adapter, **real** `SetSecurityStack` | Base 8453 |
| 1 | `hxsquid`, `havnt` | Side-token L. Same `0x9a99b4f0`. Never `0xeab52318` | Base |
| 2 | `hcbeth`, `hgsoon`, `hswbera` | Rate L, 1% skim, 99% stays | Base / BSC / Bera |
| 3 | `hsavax`, `hsethfi`, `hstkwausdc` | Rate / yield-in-share / Umbrella dual harvest | Avax / ETH / ETH |
| 4 | `bluai4y`, `horder` | C1 lockbox + closed OFT. Market exit | BSC / Arb |

Do not deploy NestVault, HNest, HevAdapter, LeafVirtualsLockbox, LeafOmnichainHolder, LeafCreate2. Do not `setShareExit`. Claim board only after batch 4’s first C1. **hJitoSOL is BATCH=5** — dest `LeafOFT` on HyperEVM is allowed after batch 4; source is Solana (`docs/SOLANA_JITOSOL.md`). Do not `DeployAdapter`. Do not `WirePeers` (that left-pads). Use `WireSolanaPeer`. No Rewarder on this dest OFT.

Branch: `feat/lz-oft-wrap`. Copy-paste below. Log every address in the PR.

---

## 0. Canary — prove the real bridge (do this first)

Inner is a **new** `LEAFTEST` you mint. Cap `0.05`. Name is `hCANARY`, not a real ticker.

```
OWNER=$OWNER GUARDIAN=$GUARDIAN FEE_RECIPIENT=$FEE_RECIPIENT DEPOSIT_CAP=50000000000000000 \
forge script script/lz/DeployCanarySource.s.sol:DeployCanarySource \
  --rpc-url base --broadcast --private-key $PRIVATE_KEY
```

Copy `CanaryInner` → `INNER`, `LeafOFTAdapter` → `SOURCE`. `INNER_TOKEN` must be unset (script reverts if set).

```
OWNER=$OWNER GUARDIAN=$GUARDIAN \
forge script script/lz/DeployCanaryDest.s.sol:DeployCanaryDest \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
```

Copy `LeafOFT` → `OFT`.

```
OAPP=$SOURCE PEER=$OFT ASSET=hcanary \
forge script script/lz/WirePeers.s.sol:WirePeers \
  --rpc-url base --broadcast --private-key $PRIVATE_KEY

OAPP=$OFT PEER=$SOURCE ASSET=hcanary \
forge script script/lz/WirePeers.s.sol:WirePeers \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
```

**Must** set the mainnet ULN. Skip this and the canary is worthless.

```
OAPP=$SOURCE \
forge script script/lz/SetSecurityStack.s.sol:SetSecurityStack \
  --rpc-url base --broadcast --private-key $PRIVATE_KEY

OAPP=$OFT ASSET=hcanary \
forge script script/lz/SetSecurityStack.s.sol:SetSecurityStack \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
```

Expect logs: Base `sendConfirms=15` `recvConfirms=5`. HyperEVM `sendConfirms=5` `recvConfirms=15`. Trio is Labs + Horizen + Canary. Not Nethermind.

```
ASSET=hcanary OAPP=$SOURCE INNER_SUPPLY_CEILING=1000000000000000000 \
forge script script/lz/OpenPeg.s.sol:OpenPeg \
  --rpc-url base --broadcast --private-key $PRIVATE_KEY

ASSET=hcanary OAPP=$OFT \
forge script script/lz/OpenPeg.s.sol:OpenPeg \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
```

Read `listingTag`, peers, caps, `getConfig` on both ULNs. Then `OPEN_BRIDGE=true` both sides.

Mint `LEAFTEST` to OWNER (`CanaryInner.mint`). Approve. Wrap a dust amount. Wait LayerZero. `hCANARY` balance on 999. Redeem back to Base.

Pass = deposit → LZ → mint → redeem, console clean, other listings not deployed.

Then `closeBridge` + `pause` both sides. **Leave the canary dead.** Do not reuse `SOURCE` / `OFT` for hxSQUID.

Canary does **not** need Rewarder, Converter fill, or Claim Board.

---

## 1. Side-token L — hxSQUID then hAVNT (Base)

Same adapter as the canary, real inners. Tiny `DEPOSIT_CAP`. `BATCH=1`.

```
BATCH=1 ASSET=hxsquid OWNER=$OWNER GUARDIAN=$GUARDIAN FEE_RECIPIENT=$FEE_RECIPIENT DEPOSIT_CAP=... \
forge script script/lz/DeployAdapter.s.sol:DeployAdapter \
  --rpc-url base --broadcast --private-key $PRIVATE_KEY

BATCH=1 ASSET=hxsquid OWNER=$OWNER GUARDIAN=$GUARDIAN \
forge script script/lz/DeployOFT.s.sol:DeployOFT \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
```

Wire with `ASSET=hxsquid`. `SetSecurityStack` both sides (`ASSET=hxsquid` on HyperEVM). OpenPeg. `ConfigureMainnetListing` `BATCH=1` sets `rewardsSelector` `0x9a99b4f0`.

hAVNT: same commands, `ASSET=havnt`. Never `0xeab52318`. Claim tx `0x26f4ca90`. Combined-redeem tx `0x24398d72` is that selector, already blacklisted.

Then Rewarder bind on 999 (`setHypeRewarder` first, then `register`). Converter allowlist. One dust wrap + `pokeRewards` + `pullYield` of QUID/AVNT (not inner).

---

## 2. Rate L — hcbETH, hgSOON, hsWBERA

`BATCH=2`. Same 1% skim. Wrap settles fee first. 99% stays in the box.

| ASSET | Chain | RPC | RateKind |
| --- | --- | --- | --- |
| `hcbeth` | Base 8453 | base | `ExchangeRate` |
| `hgsoon` | BSC 56 | bsc | `ConvertToAssets` |
| `hswbera` | Bera 80094 | berachain | `ConvertToAssets` |

HyperEVM `SetSecurityStack` / `WirePeers` **must** pass `ASSET=` so remote eid is not Base-by-default (hgSOON → 30102, hsWBERA → 30362).

Do not call `cooldownShares` / `requestUnlock` / Bera 7d NFT queue. `pullYield(inner)` on these listings is the 1% skim only.

---

## 3. ETH / Avax L — hsAVAX, hsETHFI, hstkwaUSDC

`BATCH=3`. New chains: Avalanche 43114, Ethereum 1.

| ASSET | Notes |
| --- | --- |
| `hsavax` | `GetPooledAvaxByShares`. Never `requestUnlock` |
| `hsethfi` | Yield in the receipt. **No** `setRateKind`. Never DelayedWithdraw / teller deposit |
| `hstkwausdc` | `ConvertToAssets` + `REWARDS_CONTROLLER` + `0xbb492bf5`. Never `cooldown`. Wrap **stkwaEthUSDC.v1** only |

---

## 4. C1 — BLUAI4Y then hORDER

`BATCH=4`. `DeployClosed`. `redeemEnabled` stays false. Exit is Claim Board, after wrap smoke.

| ASSET | Source | Inner |
| --- | --- | --- |
| `bluai4y` | BSC 56 | catalog inner. Farm `claimAll`. No `setShareExit` |
| `horder` | Arb 42161 | ORDER OFT. `reportLedgerPrincipal`. No CREATE2 twin |

Dest `LeafReleased` is not filled. Wait source `Paid`. LZ fees are LayerZero’s, not ours.

---

## Pass / fail (every listing)

Normal: deposit → LZ → mint → (L: redeem). Then inject wrong tag / wrong peer / closed bridge / cap / ceiling / bad selector. Each reverts, no partial state, **other listing untouched**.

After canary, answer in the PR:

1. Worst-case loss (cap, not unbounded)
2. Can guardian `closeBridge` in time
3. Does a broken listing contaminate another

Do not open batch N+1 until batch N has those three answers.

---

## 5. hJitoSOL dest OFT (after batch 4, dest only)

Source lockbox is a Solana program. **This sandbox cannot emit a `.so`.**
Grok bot builds it on a Docker machine — `docs/GROK_BOT_SOLANA.md`. This
pass only deploys HyperEVM `LeafOFT` **after** that Store PDA exists.

```
BATCH=5 ASSET=hjitosol OWNER=$OWNER GUARDIAN=$GUARDIAN \
forge script script/lz/DeployOFT.s.sol:DeployOFT \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
```

Copy `LeafOFT` → `OFT`. **Do not** set a Rewarder. Rate yield stays in remaining JitoSOL.

```
OAPP=$OFT PEER=$SOLANA_STORE_PDA ASSET=hjitosol \
forge script script/lz/WireSolanaPeer.s.sol:WireSolanaPeer \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
```

`PEER` is the OApp **Store PDA** (32 bytes). Reverts if it looks left-padded. Never `WirePeers`.

```
OAPP=$OFT ASSET=hjitosol \
forge script script/lz/SetSecurityStack.s.sol:SetSecurityStack \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
```

Expect `remoteEid=30168` `sendConfirms=5` `recvConfirms=32`. Trio Labs + Horizen + Canary on HyperEVM. Solana-side DVN trio (same names, different pubkeys) is set by the Solana program, not this script. Nethermind is forbidden on both sides.

```
ASSET=hjitosol OAPP=$OFT \
forge script script/lz/OpenPeg.s.sol:OpenPeg \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
```

Prefer `ConfigureJitoDest` (same caps, **reverts if a Rewarder is already set**):

```
OFT=$OFT \
forge script script/lz/ConfigureJitoDest.s.sol:ConfigureJitoDest \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
```

Do not `OPEN_BRIDGE=true` until the Solana Store is registered, peered to this OFT (20-byte left-padded), and the Solana ULN uses Labs+Horizen+Canary. `ConfigureMainnetListing` reverts on `BATCH=5`.

Redeem from this OFT must call `send(30168, solanaPubkey, amount)` — `sendTo` reverts `NotSolanaRecipient`.

---

## Still not this pass

- HyperEVM AMM / treasury bids
- hKAITO / hVIRTUALMAX / hSKY / ve-NFT
- NestVault v2
- C1 protocol redeem
- Reusing canary addresses as a real vault
- Compiling/deploying the Solana program (spec is `solana/leaf-jito-rate`; needs Anchor + `anchor build` on a machine with the Solana toolchain)
