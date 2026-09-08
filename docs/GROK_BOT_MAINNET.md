# Grok bot tasks — mainnet go-live

You deploy. You do **not** redesign assets, restyle the frontend, or open a
bridge because a PR merged. Branch: `feat/lz-oft-wrap`. Log every address in
the PR. `BATCH` is required. Wrong ticker reverts `NotThisBatch`.

Frontend copy is a **different** bot: [`GROK_BOT_FRONTEND.md`](GROK_BOT_FRONTEND.md).
Harvest notes: [`GROK_BOT_RECEIPTS.md`](GROK_BOT_RECEIPTS.md).
Solana `.so` detail: [`GROK_BOT_SOLANA.md`](GROK_BOT_SOLANA.md) (also inlined in §5).

---

## Hard rules

1. **Mainnet only.** HyperEVM 998 / Base Sepolia cannot run Labs + Horizen + Canary or the real confirmation split. Deleted testnet scripts stay deleted.
2. **Canary first.** Do not point any script at live xSQUID / stkAVNT / cbETH / gSOON / sWBERA until canary has deposited, minted, and redeemed on **8453 ↔ 999**. Then kill the canary. New addresses for real listings.
3. **Do not skip a batch.** Batch N+1 starts only after batch N’s three PR answers (below).
4. **Keys are three EOAs.** `OWNER` ≠ `GUARDIAN` ≠ `HARVESTER`. `PRIVATE_KEY` is OWNER. Converter is `LeafYieldConverter`, never an EOA. Do not leave this bot as owner.
5. **Do not `openBridge` on autopilot.** Read `listingTag`, peers, caps, ULN `getConfig` first. Then `OPEN_BRIDGE=true`.
6. **LZ fees are LayerZero’s.** UI and PR must say we do not take that fee.
7. **Do not deploy:** NestVault, HNest, HevAdapter, LeafVirtualsLockbox, LeafOmnichainHolder, LeafCreate2. Do not `setShareExit`. Do not wrap NCN VRTs (fragSOL / kySOL / ezSOL).

---

## Order (this is the whole job)

| BATCH | When | Tickers | Framework | Source chain |
| ---: | --- | --- | --- | --- |
| **0** | first | `hcanary` | Toy ERC-20, L adapter, **real** ULN | Base 8453 |
| **1** | canary dead | `hxsquid` then `havnt` | Side-token L. `0x9a99b4f0`. Never `0xeab52318` | Base 8453 |
| **2** | batch 1 passed | `hcbeth` then `hgsoon` then `hswbera` | Rate L, 1% skim, 99% in receipt | Base / BSC 56 / Bera 80094 |
| **3** | batch 2 passed | `hsavax` then `hsethfi` then `hstkwausdc` | Rate / yield-in-share / Umbrella | Avax 43114 / ETH 1 / ETH 1 |
| **4** | batch 3 passed | `bluai4y` then `horder` | C1 lockbox + closed OFT. Market exit | BSC 56 / Arb 42161 |
| **5** | batch 4 passed **and** Store PDA exists | `hjitosol` | Solana lockbox + dest `LeafOFT`. No Rewarder | Solana 30168 → HyperEVM 999 |

jupSOL / mSOL / bnSOL / INF / hKAITO / hVIRTUALMAX / hSKY / Nest v2 are **not this job**.

---

## Confirmations (send = this chain, receive = remote)

Copying one number onto both ULNs is a DVN mismatch. Script already splits them. Check the logs.

| This chain | sendConfirms | When dest is HyperEVM, recvConfirms |
| --- | ---: | ---: |
| HyperEVM 999 | **5** | (recv = the source: 15 Base/BSC/Arb/ETH, 12 Avax, 32 Solana) |
| Base 8453 | 15 | 5 |
| BSC 56 | 15 | 5 |
| Arb 42161 | 15 | 5 |
| ETH 1 | 15 | 5 |
| Bera 80094 | 15 | 5 |
| Avax 43114 | **12** | 5 |
| Solana (program, not this script) | **32** | 5 |

Trio on every EVM we touch: **Labs + Horizen + Canary**. Sorted ascending. **Never Nethermind.**

HyperEVM `SetSecurityStack` / `WirePeers` **must** pass `ASSET=` so remote eid is not Base-by-default (`hgsoon` → 30102, `hswbera` → 30362, `hsethfi`/`hstkwausdc` → 30101, `hsavax` → 30106, `horder` → 30110, `hjitosol` → 30168).

---

## Pass / fail (every listing, including canary)

Normal: deposit → LZ → mint → (L: redeem). Then inject: wrong tag, wrong peer, closed bridge, cap, ceiling, bad selector. Each reverts, no partial state, **other listing untouched**.

After each ticker, comment on the PR:

1. Worst-case loss (cap, not unbounded)
2. Can guardian `closeBridge` in time
3. Does a broken listing contaminate another

Do not open batch N+1 until those three exist for every ticker in batch N.

---

## 0. Canary — prove the real bridge

Inner is a **new** `LEAFTEST` you mint. Cap `0.05`. Name `hCANARY`. Throwaway.

```
OWNER=$OWNER GUARDIAN=$GUARDIAN FEE_RECIPIENT=$FEE_RECIPIENT DEPOSIT_CAP=50000000000000000 \
forge script script/lz/DeployCanarySource.s.sol:DeployCanarySource \
  --rpc-url base --broadcast --private-key $PRIVATE_KEY
```

Copy `CanaryInner` → `INNER`, `LeafOFTAdapter` → `SOURCE`. `INNER_TOKEN` must be unset.

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

Expect: Base `sendConfirms=15` `recvConfirms=5`. HyperEVM `sendConfirms=5` `recvConfirms=15`. Trio Labs + Horizen + Canary.

```
ASSET=hcanary OAPP=$SOURCE INNER_SUPPLY_CEILING=1000000000000000000 \
forge script script/lz/OpenPeg.s.sol:OpenPeg \
  --rpc-url base --broadcast --private-key $PRIVATE_KEY

ASSET=hcanary OAPP=$OFT \
forge script script/lz/OpenPeg.s.sol:OpenPeg \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
```

Read `listingTag`, peers, caps, `getConfig` on both ULNs. Then `OPEN_BRIDGE=true` both sides.

Mint `LEAFTEST` to OWNER (`CanaryInner.mint`). Approve. Wrap dust. Wait LayerZero. `hCANARY` on 999. Redeem back to Base.

Pass = deposit → LZ → mint → redeem, console clean, no other listing deployed.

Then `closeBridge` + `pause` both sides. **Leave it dead.** Do not reuse `SOURCE` / `OFT` for hxSQUID.

Canary does **not** need Rewarder, Converter fill, or Claim Board.

---

## L listing recipe (batches 1–3)

Same six scripts every time. Swap `ASSET`, `BATCH`, source `--rpc-url`. Tiny `DEPOSIT_CAP`.

```
BATCH=$BATCH ASSET=$ASSET OWNER=$OWNER GUARDIAN=$GUARDIAN FEE_RECIPIENT=$FEE_RECIPIENT DEPOSIT_CAP=$CAP \
forge script script/lz/DeployAdapter.s.sol:DeployAdapter \
  --rpc-url $SOURCE_RPC --broadcast --private-key $PRIVATE_KEY
# → SOURCE

BATCH=$BATCH ASSET=$ASSET OWNER=$OWNER GUARDIAN=$GUARDIAN \
forge script script/lz/DeployOFT.s.sol:DeployOFT \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
# → OFT

OAPP=$SOURCE PEER=$OFT ASSET=$ASSET \
forge script script/lz/WirePeers.s.sol:WirePeers \
  --rpc-url $SOURCE_RPC --broadcast --private-key $PRIVATE_KEY

OAPP=$OFT PEER=$SOURCE ASSET=$ASSET \
forge script script/lz/WirePeers.s.sol:WirePeers \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY

OAPP=$SOURCE ASSET=$ASSET \
forge script script/lz/SetSecurityStack.s.sol:SetSecurityStack \
  --rpc-url $SOURCE_RPC --broadcast --private-key $PRIVATE_KEY

OAPP=$OFT ASSET=$ASSET \
forge script script/lz/SetSecurityStack.s.sol:SetSecurityStack \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY

ASSET=$ASSET OAPP=$SOURCE \
forge script script/lz/OpenPeg.s.sol:OpenPeg \
  --rpc-url $SOURCE_RPC --broadcast --private-key $PRIVATE_KEY

ASSET=$ASSET OAPP=$OFT \
forge script script/lz/OpenPeg.s.sol:OpenPeg \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY

BATCH=$BATCH ASSET=$ASSET SOURCE=$SOURCE HARVESTER=$HARVESTER CONVERTER=$CONVERTER OWNER=$OWNER \
forge script script/lz/ConfigureMainnetListing.s.sol:ConfigureMainnetListing \
  --rpc-url $SOURCE_RPC --broadcast --private-key $PRIVATE_KEY
```

Then dust wrap + inject failures + PR answers. `OPEN_BRIDGE=true` only after the reads.

`ConfigureMainnetListing` reverts on C1 and on `hjitosol`. HARVESTER and CONVERTER must not be OWNER.

---

## 1. Side-token L — hxSQUID then hAVNT

`BATCH=1`. `$SOURCE_RPC=base`. Inner from catalog (script pins it).

`ConfigureMainnetListing` sets `rewardsSelector` `0x9a99b4f0` for both.

hAVNT: never `0xeab52318` (`claimRewardsAndRedeem`). Claim tx `0x26f4ca90`. Combined-redeem tx `0x24398d72` is a **hash**, not a selector — already documented; blacklist is `0xeab52318`.

After both tickers: Rewarder bind on 999 (`setHypeRewarder` first, then `register`). Converter allowlist. One dust wrap + `pokeRewards` + `pullYield` of **QUID / AVNT**, not inner. `pullYield(inner)` must revert `CannotPullInner`.

---

## 2. Rate L — hcbETH, hgSOON, hsWBERA

`BATCH=2`. Wrap/redeem **settle the 1% skim first**. 99% stays in the receipt. No holder `claim()` HYPE.

| ASSET | SOURCE_RPC | RateKind | Never |
| --- | --- | --- | --- |
| `hcbeth` | base | `ExchangeRate` | treat donations as yield |
| `hgsoon` | bsc | `ConvertToAssets` | `cooldownShares` / `cooldownAssets` / SOON `deposit` |
| `hswbera` | berachain | `ConvertToAssets` | Bera 7d NFT `requestUnlock` |

`pullYield(inner)` **is** the 1% skim. Dust fee (surplus < 100 atoms) is 0; watermark still moves; do not claw later.

Do not print a protocol APR on a dust vault.

---

## 3. ETH / Avax L — hsAVAX, hsETHFI, hstkwaUSDC

`BATCH=3`. New RPCs: Avalanche, Ethereum.

| ASSET | SOURCE_RPC | Notes |
| --- | --- | --- |
| `hsavax` | avalanche | `GetPooledAvaxByShares`. Never `requestUnlock` |
| `hsethfi` | ethereum | Yield in the receipt. **No** `setRateKind`. Never DelayedWithdraw / teller deposit |
| `hstkwausdc` | ethereum | `ConvertToAssets` + `REWARDS_CONTROLLER` + `0xbb492bf5`. Never `cooldown`. Wrap **stkwaEthUSDC.v1** only. Umbrella will upgrade — users exit that receipt, we do not auto-migrate |

`hstkwausdc` needs env `REWARDS_CONTROLLER` on `ConfigureMainnetListing`.

---

## 4. C1 — BLUAI4Y then hORDER

`BATCH=4`. `DeployClosed`. `redeemEnabled` stays **false**. Exit is Claim Board, **after** wrap smoke. No `setShareExit`. No CREATE2 twin for ORDER (Arb only).

```
BATCH=4 ASSET=$ASSET INNER_TOKEN=$INNER OWNER=$OWNER GUARDIAN=$GUARDIAN FEE_RECIPIENT=$FEE_RECIPIENT DEPOSIT_CAP=$CAP \
forge script script/lz/DeployClosed.s.sol:DeployClosed \
  --rpc-url $SOURCE_RPC --broadcast --private-key $PRIVATE_KEY
# → SOURCE (LeafInboundLockbox)

BATCH=4 ASSET=$ASSET OWNER=$OWNER GUARDIAN=$GUARDIAN \
forge script script/lz/DeployClosed.s.sol:DeployClosed \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
# → OFT (LeafClosedOFT)
```

Then WirePeers + SetSecurityStack + OpenPeg with `ASSET=`. Then pin the farm:

```
BATCH=4 ASSET=$ASSET SOURCE=$SOURCE HARVESTER=$HARVESTER CONVERTER=$CONVERTER OWNER=$OWNER \
forge script script/lz/ConfigureClosedListing.s.sol:ConfigureClosedListing \
  --rpc-url $SOURCE_RPC --broadcast --private-key $PRIVATE_KEY
```

`horder` must be `--rpc-url arb` (42161). Script sets Orderly proxy, `stakeOrder`, public types **10 and 17 only**, unstake 2/3/4 stay owner. Inner must be OFT `0x4E200fE2…`, never ETH `0xABD4…`. Solvency is `reportLedgerPrincipal`, not `ORDER.balanceOf(lockbox)`.

`bluai4y` must be BSC. Script sets `stake(amount, 4)` + `claimAll`. Do not `setShareExit`. Check dest `redeemEnabled == false`.

After wrap smoke: guardian reports ledger (hORDER) before a second mint. Claim Board only after that smoke. Dest `Filled` is **not** paid — wait source `Paid`. Protocol does not bid. 90d TTL. 1% of ask is buyer incentive, not protocol fee.

Do not enable protocol redeem to “help” a seller. Do not `DeployOmnichainLockbox` for ORDER.

| ASSET | SOURCE_RPC | Inner | Harvest |
| --- | --- | --- | --- |
| `bluai4y` | bsc | catalog. Farm `claimAll` | extra BLUAI only |
| `horder` | arb | ORDER OFT | `reportLedgerPrincipal`. Occupancy ≠ harvest |

Claim Board (escrow + fill) only after the first C1 wrap smoke. Dest `Filled` is **not** paid — wait source `Paid`. Protocol does not bid. 90d TTL. 1% of ask is buyer incentive, not protocol fee.

Do not enable protocol redeem to “help” a seller.

---

## 5. hJitoSOL — Solana source + HyperEVM dest

`BATCH=5`. **Do this after batch 4.** NCN is out. Wrap JitoSOL mint only.

Mint `J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn`. Pool (read-only) `Jito4APyf642JPZPx3hGc6WWJ8zPKtRbRs4P815Awbb`. Spec: `solana/leaf-jito-rate` (`cargo test --manifest-path solana/leaf-jito-rate/Cargo.toml`). If the on-chain program disagrees with those tests, the program is wrong.

### 5a. Produce the `.so` (Docker machine — not the architect sandbox)

Pinned to LZ `examples/oapp-solana`. Do not float versions. Do not `cargo-build-sbf` without Docker. Do not check in a hand-built `.so`.

| Tool | Version |
| --- | --- |
| Rust | **1.84.1** (LZ pin, not sandbox 1.98) |
| Solana CLI | **2.2.20** |
| Anchor | **0.31.1** |
| Docker | required |

```
sh -c "$(curl -sSfL https://release.anza.xyz/v2.2.20/install)"
cargo install --git https://github.com/coral-xyz/anchor avm --locked
avm install 0.31.1 && avm use 0.31.1

solana-keygen new -o solana/target/deploy/leaf_jito_lockbox-keypair.json
anchor keys sync

# Wire our Store/lock/harvest into the LZ OApp template. Do not invent Endpoint remaining-accounts.
anchor build -v -e MYOAPP_ID=<PROGRAM_ID>
# → target/verifiable/leaf_jito_lockbox.so

solana program deploy \
  --program-id solana/target/deploy/leaf_jito_lockbox-keypair.json \
  target/verifiable/leaf_jito_lockbox.so \
  -u mainnet-beta
```

Init Store PDA (seed `b"Store"`). Create JitoSOL escrow ATA (owner = Store). Harvest ATA for the 1% skim. Set Solana ULN: Labs `4VDjp6XQaxoZf5RGwiPU9NR1EXSZn2TP4ATMmiSzLfhb` + Horizen `HR9NQKK1ynW9NzgdM37dU5CBtqRHTukmbMKS7qkwSkHX` + Canary `7jMeX5mzXnSSKYd8DxBDP4xMnkNFZZZm5W28FWUTbwU3`. Never Nethermind `GPjyWr8vCotGuFubDpTxDxy9Vj1ZeEN4F2dwRmFiaGab`. Receive confirmations **32**. Dest peer = HyperEVM LeafOFT, **20-byte left-padded**. Peer freeze after first set.

Forbidden CPI: stake pool, interceptor, vault, restaking. No `HarvestOther` of the Jito mint. No VRT wrap.

Print **Store PDA** (32-byte). That is the EVM peer, not the program id.

### 5b. HyperEVM dest OFT (only after Store PDA exists)

`ConfigureMainnetListing` reverts. `WirePeers` reverts (it left-pads). `DeployAdapter` is wrong.

```
BATCH=5 ASSET=hjitosol OWNER=$OWNER GUARDIAN=$GUARDIAN \
forge script script/lz/DeployOFT.s.sol:DeployOFT \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
# → OFT. Do not setHypeRewarder.

OAPP=$OFT PEER=$SOLANA_STORE_PDA ASSET=hjitosol \
forge script script/lz/WireSolanaPeer.s.sol:WireSolanaPeer \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
# PEER is 32-byte Store PDA. Reverts if it looks left-padded.

OAPP=$OFT ASSET=hjitosol \
forge script script/lz/SetSecurityStack.s.sol:SetSecurityStack \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
# Expect remoteEid=30168 sendConfirms=5 recvConfirms=32
```

```
OFT=$OFT \
forge script script/lz/ConfigureJitoDest.s.sol:ConfigureJitoDest \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
```

Reverts if a Rewarder is already set. Do not `OPEN_BRIDGE=true` until Solana Store is peered to this OFT and Solana ULN is the trio above.

Redeem: `oft.send(30168, solanaPubkey, amount)`. `sendTo` reverts `NotSolanaRecipient`. User must paste a 32-byte Solana address. Unlock pays remaining JitoSOL, never the whole ATA. 99% of rate yield stays in the receipt; protocol skim is 1% of surplus (0 if surplus < 100 atoms).

Smoke: lock dust JitoSOL → LZ → hJitoSOL on 999 → send back to a Solana pubkey → remaining JitoSOL. Then inject wrong tag / wrong peer / cap. PR three answers.

---

## Still not this job

- HyperEVM AMM / treasury bids
- hKAITO / hVIRTUALMAX / hSKY / ve-NFT
- NestVault v2
- C1 protocol redeem
- Reusing canary addresses as a real vault
- jupSOL / mSOL / bnSOL / INF
- NCN restake / VRT wrap
- Compiling `.so` on the architect sandbox
- Frontend restyle (`GROK_BOT_FRONTEND.md` is the other bot)
- Preview updates
