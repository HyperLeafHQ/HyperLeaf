# Stable vaults — 2026-09-10 chain check

Never wrap the stable. Wrap the **receipt**. HyperEVM empty on all four.

## hDAI — later, capped

Gauntlet DAI Core V1 `0x500331c9fF24D9d11aee6B07734Aa72343EA74a5` Ethereum.
`symbol=gtDAIcore` · `asset()=DAI 0x6B17…1d0F` · `convertToAssets(1e18)=1.176e18` · `totalAssets≈2.14M DAI`.

Wrap **shares** only. Cap **100k DAI**. Do not advertise APY. Freeze `asset()==DAI`. Never Blue market.

## hRLUSD — later, same Morpho family

Sentora RLUSD Main V2 `0x6dc58a0fdfc8d694e571dc59b9a52eeea780e6bf` Ethereum.
`symbol=senRLUSDv2` · `asset()=RLUSD 0x8292Bb45…17eD` (Ripple official) · `convertToAssets(1e18)=1.011e18` · `totalAssets≈350M`.

Wrap **senRLUSDv2** only. Never RLUSD, never Blue. 1% skim on `convertToAssets`. One vault = one listing. Do not auto-list every Morpho vault.

## BTWUSDT — research (BSC, CeDeFi)

Bitway Core Alpha share `0x73af543D809C8D3414e5B92b3aa2c25b182Ba3A1` on **BSC** (not a Bitway L1). Vault `0xb82E32…B63`, `paused=false`. Supply ≈23.9M. Official [staking contracts](https://docs.bitway.com/bitway-earn/staking-contracts).

Yield is Bitway strategy + **CEX custody**. Normal unstake ~7d; flash has a penalty. Token is **not** ERC-4626. Wrap **BTWUSDT** only, never USDT. Do not market as trustless. LZ eid 30102 exists; still not a BATCH.

## HertzFlow USD1 — watch

`0xeeA83A77Eb978Be804Da038aEdd318dbFd3da9c6` **is** the ERC-20: `HLV [USD1-USD1]`, supply ≈6.76M. Official handler list still “to be published” for BSC mainnet. No `convertToAssets`. Perp LP: share price can fall; withdraw can stall. Campaign USD1 is not backing.

Wrap **HLV** only, never raw USD1. Block until Reader + deposit/withdraw handlers are in their docs and fork-tested.

`NotThisBatch`.
