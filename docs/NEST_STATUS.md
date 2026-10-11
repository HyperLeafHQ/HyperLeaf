# Nest status

Read this before any Nest deploy, frontend change, or bot runbook.
If another doc disagrees on **which address is current**, this page wins.
Chain read: HyperEVM 999, 2026-10-11.

Do not redeploy a vault to "upgrade" it. veNEST sits in the vault.
Do not upgrade an existing Gate proxy onto a newer implementation unless that
exact proxy was deployed from that implementation. `hypeReserved` and the
vault pointer are set only in `initialize`.

## Code, newest first

| File | What it is | Deploy it? |
| --- | --- | --- |
| `src/NestVaultC1.sol` | No-redeem vault. Frozen-week HYPE, 16-week catch-up. | Only as a **new** vault, from PR #113. |
| `src/EpochHNestGateV3.sol` | UUPS gate. Week booked once. 8-day delay. | Only as a **new** proxy, same deploy as the vault above. |
| `src/EpochHNestGateV2.sol` | Previous gate. Not a proxy. | No. Already on `0x567E…`. |
| `src/EpochHNestGate.sol` | First gate. | No. |
| `src/NestVault.sol` | Redeem vault. | No. |
| `src/HNest.sol` / `src/HevAdapter.sol` | Share token and HEV attach. One pair per vault. | Only beside a new vault. |

PR [#113](https://github.com/HyperLeafHQ/HyperLeaf/pull/113) head
`1873705f0778305ffebfc8110b25cfa1b5231db0` is the code GO.
It is **not merged** and **not deployed**. `main` does not contain it.
Deploy from that SHA, not from `main`. Deposits stay off until a separate GO.
The only later signature from FINAL is `setDepositsEnabled(true)`.

## Addresses

`deposits` is `depositsEnabled()` as read on 2026-10-11.

| Set | Vault | hNEST | Gate | Deposits | Use |
| --- | --- | --- | --- | --- | --- |
| v1 | `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` | `0x2101621F51D7E05518D6680C62d04Ad47bC4e05D` | none (`depositGate` reverts) | true | Abandoned. Do not show. |
| C1, old | `0xaE7C4B1bdbEeD5B5923D856Ae53DF357CC86755c` | `0x6dC42a28CCDAfA0F925953F13439d5976Ef2122F` | `0x900b53081E91EE9aeC318de2869772BA5c46a6A7` | true | Old open set. Do not send new users here. |
| Gate V2 | `0x77F2682949978E8228fEC661EC45bAD5C6b9d765` | `0x584ECE6d1beD8308D0D212bF3D82Ec76B2069017` | `0x567E0856429eBb85cB168bB0552E42eE899E457b` | true | Opened for the frontend after the V2 audit. Accounting bugs in #110 / #112. Do not upgrade this gate. |
| V3, first binary | `0x3f0219755BeBA32A27b66F455444e2D1E64B420E` | `0x763fEA905358E51310dfe3a916c99E1FAD448FC9` | `0xc45fcD2201ad1DCC527CCFdE328eCEA7F5357020` | **false** | Deployed from `f4d9772`, then blocked. Do not open. Do not upgrade the proxy. |
| Next | not deployed | — | — | — | Fresh vault + fresh proxy from `1873705`. |

Market for the old open hNEST: `0x6f29EA2894570b893B00C3f2305c184D7080CB34`.
Abandoned market `0xFa77Dfb30DeCca4D9597C6764A698996B226b53A`. Do not reuse it.
The next hNEST is a different token. It does not use that market until a separate market deploy.

## Roles

| Role | Address |
| --- | --- |
| Owner (FINAL) | `0x24458f0Bc44c4607172d1151CD938012be33156e` |
| Keeper and deployer | `0x7f78E9D21886e18C83832E549467d08cDb93BF18` |
| Guardian | `0x12DF4528e7CC3dB07A509C966C6405b69a25Ef2E` |
| Fee recipient | `0x76c8c4586F0A3D335Cf7192ebBb4fE6ed5af3804` |

`0xc321DD8826a30D8a6D973821a3dB7b8090955887` is burned.
`deployments/mainnet-999.json` still records it. Do not load that key.

## Keeper, next vault only

- `rollEpoch` once a week.
- `bookEpoch` on a week that has dust. A 1 wei donation makes an empty finalize revert.
- If `bookVerifiedYield` has not run for more than 16 weeks, `checkpointHype(feeRecipient)` first.
- `depositCap == 0` means no cap. It is not "unset".

## Where the rest of the repo is

| Path | What |
| --- | --- |
| `src/lz/` | Leaf OFT, claim market, per-asset policy. Not the Nest vault. |
| `src/premarket/` | Pre-TGE escrow. Not a Leaf. |
| `src/adapters/` | GT / POL / VVV staking adapters. Not deployed as Nest. |
| `solana/leaf-jito/` | hJitoSOL. Program not deployed. |
| `docs/GROK_BOT_MAINNET.md` | Wrap batches. "Do not deploy NestVault" still applies unless a Nest GO names a SHA. |
| `docs/GROK_BOT_GATE.md` | Old gate deploy. Do not run it. |
| `docs/GROK_BOT_LEAF_MARKET.md` | hORDER / BLUAI markets. Not a Nest vault deploy. |

## Tests that match the current Nest code

`test/NestVaultC1.t.sol`, `test/EpochHNestGateV3.t.sol`.
V1 and V2 tests stay. They cover the contracts already on-chain. They are not the next deploy.
