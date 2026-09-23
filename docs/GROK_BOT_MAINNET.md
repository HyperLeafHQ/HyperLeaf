# Grok bot tasks — mainnet go-live

> **Status 2026-09-22: archived as a live-ops checklist.** Live surface:
> **10 Leafs** (hNEST, hQUID, hAVNT, hgSOON, hslisBNB, hsiBERA, hsAVAX, hstkwaUSDC, **hLBTCv**, BLUAI4Y) **+ 2 pre-market** (VAR, Predict).
> Addresses: [`listings/catalog.json`](../listings/catalog.json) `live` objects.
> This file stays as the **deploy cookbook** for what is not live yet:
> BATCH 3 **done** (`hlbtcv` LIVE; `hlbtc` parked),
> `horder` (wrap smoke PASS, **not LIVE**, no Market — do not redeploy, do not GO Phase 3),
> Nado points `createMarket` (n=3, **no broadcast until GO**),
> Quantus QTC native OTC (`DeployNativeOtcQtc.s.sol` — **new factory, never n=4 on the live VAR book, no broadcast until GO**),
> and `hjitosol` (BATCH 5).
> Do **not** deploy Ink adapter/OFT — official INK ERC-20 is not posted.
> Do not treat the narrative below as "do this next" unless the ticker is still unchecked.
> Do **not** wire 50-cap hQUID/hAVNT or 100-cap BLUAI.

You deploy. You do **not** redesign assets, restyle the frontend, or open a
bridge because a PR merged. Branch: **`main`**. Log every address in
issue [#7](https://github.com/HyperLeafHQ/HyperLeaf/issues/7) or a deploy comment — not a frontend rewrite.
`BATCH` is required. Wrong ticker reverts `NotThisBatch`.

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
7. **Do not deploy:** NestVault, HNest, HevAdapter, LeafVirtualsLockbox, LeafOmnichainHolder, LeafCreate2. Do not `setShareExit`. Do not wrap NCN VRTs (fragSOL / kySOL / ezSOL). **Leaf Market for live hNEST is a different job:** [`GROK_BOT_LEAF_MARKET.md`](GROK_BOT_LEAF_MARKET.md). Do not wait for this BATCH table. Do not deploy `LeafClaimFill` for hNEST.
8. **`main` is live + the next deploy only.** Live: hNEST + hQUID + hAVNT + hgSOON + hslisBNB + hsiBERA + hsAVAX + hstkwaUSDC + **hLBTCv** + BLUAI4Y + VAR/Predict pre-market. Next **broadcast** is **not** automatic. **`hlbtc` is parked.** **`horder` wrap is deployed — do not redeploy, do not mark LIVE, do not deploy Market until a separate GO.** Nado points `createMarket` is a separate queued cookbook — do not broadcast. Do not deploy hINK wrap. **`hsWBERA` is parked**. SOURCE `0x4C862bC0…` is **chain-keyed**: 1 hstkwaUSDC / 43114 hsAVAX / 80094 hsiBERA / **42161 hORDER** / 56 dead BLUAI. hLBTCv SOURCE on 1 is **`0x615487eD…`** (unique). hORDER converters are **not** `0xc89273AC…`.
   - hslisBNB rate: `LeafListaPolicy` + `RateKind.ConvertSnBnbToBnb` on `main` after this pin PR. Never `convertToAssets` on the slisBNB token.
   - hsAVAX jump 300 is on `ConfigureMainnetListing` `ASSET=hsavax`. `hlbtcv` **LIVE**. `hlbtc` parked.

---

## Order (this is the whole job)

| BATCH | When | Tickers | Framework | Source chain |
| ---: | --- | --- | --- | --- |
| **0** | first | `hcanary` | Toy ERC-20, L adapter, **real** ULN | Base 8453 |
| **1** | canary dead | `hxsquid` then `havnt` | Side-token L. `0x9a99b4f0`. Never `0xeab52318` | Base 8453 |
| **2** | **LIVE** | `hgsoon` `hslisbnb` `hsibera` | Rate L, 1% skim. SOURCE `0x4C86` on 80094 is hsiBERA | BSC 56 / Bera 80094 |
| **3** | **LIVE** (hsAVAX + hstkwaUSDC + hLBTCv); `hlbtc` parked | `hlbtcv` SOURCE `0x615487eD…` | LBTCv Veda getRateInQuote(LBTC) | ETH |
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
| Robinhood 4663 | 15 | 5 |
| Solana (program, not this script) | **32** | 5 |

Trio on every EVM we touch: **Labs + Horizen + Canary**. Sorted ascending. **Never Nethermind.**

HyperEVM `SetSecurityStack` / `WirePeers` **must** pass `ASSET=` so remote eid is not Base-by-default (`hgsoon`/`hslisbnb` → 30102, `hsibera` → 30362, `hink` → 30339, `hstkwausdc` → 30101, `hsavax` → 30106, `horder` → 30110, `hjitosol` → 30168, `hsteakusdg` → 30416). `hsteakusdg` is a later pin, **not a BATCH — no GO**.

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

See git history `95603d0` `docs/GROK_BOT_MAINNET.md` for the original canary / L-recipe / batch 1–3 command blocks. Those batches are live; do not rerun them.

---

## 2b. hslisBNB / hsiBERA LIVE

`BATCH=2` remainder is **LIVE**. Do not redeploy.

- **hslisBNB LIVE** SOURCE `0xf16E73739787c7F5C92574e536c3fb007191801d` / OFT `0x62cCB35Ed6EC5833379389719a7EE70D33A8ace7` / Conv BSC `0x988cA9957F2Bea52881a91395829D9f7c525D6eB`. Owner FINAL. Wrap slisBNB only.
- **hsiBERA LIVE** SOURCE `0x4C862bC0922556e1bF02561bcf6Ff25e43826D5C` (**Berachain 80094**) / OFT `0xE22b448DF578EA079Ea6f1EF5316B95cabA590f2` / Conv `0xc89273ACB22a4e1df81A396FE0Bf6eD6E2CA6fD2`. Inner siBERA. Same SOURCE hex on 1 / 43114 / 56 — never mix.
- **hsWBERA** parked. Do not `GO` `ASSET=hswbera`.

Do not comment `GO` on #69 for these tickers.

---

## 3a. hsAVAX LIVE

`BATCH=3` first ticker is **LIVE**. Do not redeploy.

- **hsAVAX LIVE** SOURCE `0x4C862bC0922556e1bF02561bcf6Ff25e43826D5C` (**Avalanche 43114**) / OFT `0x304abA885393aC13e34655daf48C2Ab8D0B6078f` / Conv `0xc89273ACB22a4e1df81A396FE0Bf6eD6E2CA6fD2`. Inner sAVAX. `maxRateJumpBps=300`. Same SOURCE/Conv hex on 1 / 80094.
- **hstkwaUSDC LIVE** SOURCE `0x4C862bC0922556e1bF02561bcf6Ff25e43826D5C` (**Ethereum 1**) / OFT `0x2D694ef80ce88c47568fD0d128Ed6C920193DAA8` / Conv `0xc89273ACB22a4e1df81A396FE0Bf6eD6E2CA6fD2`. Inner stkwaEthUSDC.v1. `shareScale=1e12`. Wrap stk v1 only.
- Remainder: none. `hlbtcv` **LIVE**. `hlbtc` parked.

Do not comment `GO` on #69 for these tickers.

---

## 4. C1 — BLUAI4Y then hORDER

`BATCH=4`. `DeployClosed`. `redeemEnabled` stays **false**. Exit is Leaf Market, **after** wrap smoke. No `setShareExit`. No CREATE2 twin for ORDER (Arb only).

`horder` must be `--rpc-url arb` (42161). Script sets Orderly proxy, `stakeOrder`, public types **10 and 17 only**, unstake 2/3/4 stay owner. Inner must be OFT `0x4E200fE2…`, never ETH `0xABD4…`. Solvency is `reportLedgerPrincipal`, not `ORDER.balanceOf(lockbox)`.

`bluai4y` is **LIVE**. Frontend cutover **done** (`hyperleaf-web@d9b57c2`). Owner accepted ×7. Pin: [`listings/catalog.json`](../listings/catalog.json) `bluai4y.live` / `deadSet`.

- LIVE SOURCE `0x4360794c42BB437B156F20b33325dAC84B7e6d8a` / OFT `0x8F25a342b93f623A07e7dF8b691a729A6e39C439` / Rewarder `0xbe1948972b120F82D28C32D3e3cbCA8c7Ec9A8A1` / Escrow `0x367FB8667919dD94874C0a48156C94E0D254d43c` / Fill `0xE3E4B14d1c3d06297eca4d9B61b3dFa4d37e3b80` / Conv BSC `0x09161B03f1A630586a3a6297B22215d8f007dB5a` / Conv HEVM `0xa5DFa3Df9aFcde719ab6ee75C6F5Ec3E86DD7937`.
- Dead 100-cap: SOURCE `0x4C862bC0922556e1bF02561bcf6Ff25e43826D5C` / OFT `0xD54A90aeB220530D00343d4442ac50C0836f2F45` / Rewarder `0x3E29CE06a56fCE05Ce196e799d37Adf1dFD58407` / Escrow `0x1AD291026DF7EE2007E48FbEf3d37B4586073207` / Fill `0xC584DC17299ED969063a97a50a3070F36CeF3eB3` / Conv BSC `0x453a4DDF03521FD25ED97289A5bE3464f1F740FF` / Conv HEVM `0x0446aB74935442a22050581A7Ea69a4354637f08`.
- On-chain `depositCap=1e30` · peg 0/0 · `supplyCap=0` · ceiling `2e28`. **Do not `setDepositCap(0)` on 0x436079**.
- Conv BSC allowlist (2026-09-16): `setLockbox(SOURCE)`, `setToken(BLUAI)`, `setOutput(USDC)` done. Escrow `setMarket` rewardId = `keccak256("bluai4y")` done. `setRoute` / `setMinPrice` still open.

Remaining in this section: **hORDER Market only, and only after a new human GO.** Wrap is done — do not redeploy.

- SOURCE Arb `0x4C862bC0922556e1bF02561bcf6Ff25e43826D5C` / OFT `0x06C345fC16F5943021dDabefFBF14D5378c86A53` / Conv Arb `0xe86961EAF3CD4ED87497641fF32E55875aB7189f` / Conv HEVM `0x4263B0967A0eE9F88329EF3334c513e0203C87FF` / Rewarder `0x4f8c69950a7dE39612eDbc01ce5426C79e791ce0`.
- Owner FINAL accepted. `redeemEnabled=false`. `bridgeOpen=true`. `farmNativeFee=0.001 ether`. Public 10/17. **Not frontend LIVE.**
- New escrow + Arb fill when GO'd. Never BLUAI escrow `0x367FB8…`. Dest `Filled` is **not** paid — wait source `Paid`. Protocol does not bid. 90d TTL. 1% of ask is buyer incentive. Do not enable protocol redeem. Do not `DeployOmnichainLockbox` for ORDER.

**Deploy cookbook for next week's bot:** GitHub issue **[#69](https://github.com/HyperLeafHQ/HyperLeaf/issues/69)**. Do not broadcast until a human comments `GO` on that issue. Native-fee split is already on `main` (#70). Do not `GO` for hslisBNB / hsiBERA from this issue.

Live **hNEST** Leaf Market is **not this section**. See [`GROK_BOT_LEAF_MARKET.md`](GROK_BOT_LEAF_MARKET.md).

---

## 5. hJitoSOL — Solana source + HyperEVM dest

`BATCH=5`. **Do this after `horder` smoke, or in parallel only after Store PDA exists.** NCN is out. Wrap JitoSOL mint only.

Full `.so` / Store PDA / `WireSolanaPeer` / `ConfigureJitoDest` steps: [`GROK_BOT_SOLANA.md`](GROK_BOT_SOLANA.md) and git `95603d0` §5. Do not compile `.so` on the architect sandbox. Do not set a Rewarder on hJitoSOL.

---

## Still not this job

- HyperEVM AMM / treasury bids
- hKAITO / hVIRTUALMAX / hSKY / ve-NFT
- NestVault v2 / NestVaultC1 / replacing live hNEST vault
- C1 protocol redeem
- Reusing canary addresses as a real vault
- jupSOL / mSOL / bnSOL / INF
- NCN restake / VRT wrap
- Compiling `.so` on the architect sandbox
- Frontend restyle (`GROK_BOT_FRONTEND.md` is the other bot)
- NFT lockbox (`LeafNftLockbox` / hveAERO). Code exists. **Not a BATCH.**
