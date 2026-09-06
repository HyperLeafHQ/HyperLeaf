# HyperLeaf

**Every asset deserves liquidity. Every yield deserves a market.**

HyperLeaf is a multi-chain liquid staking protocol built on HyperEVM. Deposit any supported staking asset, receive a freely tradable ERC-20 receipt token that tracks a Nest-managed lock (e.g. veNEST → HEV), and exit via the market or a redemption queue — without waiting out every lock yourself.

Where Hyperliquid brings liquidity to trading, HyperLeaf brings liquidity to staking.

---

## The Problem

Across every chain, the same pattern repeats: projects launch staking programs, lock up supply, and distribute rewards to long-term holders. The mechanics work. The incentives are real. But the experience is broken.

- Locked positions cannot exit before expiry
- Staking rewards accumulate but cannot be deployed elsewhere
- Users who need liquidity must choose between yield and flexibility
- Small-cap assets with genuine staking programs have no LST market at all

The result is stranded capital. Users bear full downside risk with no ability to manage it. When conditions change, there is nowhere to go.

## The Solution

HyperLeaf wraps staking positions into liquid ERC-20 receipt tokens — one per supported asset — deployable, tradable, and composable within the HyperEVM ecosystem.

A user who deposits into HyperLeaf does not give up the underlying Nest position. They gain an exit. The vault holds veNEST attached to Nest’s HEV automation. Nest may still compound on its side; **HyperLeaf does not currently raise hNEST share price via `recordCompound` (disabled until a verifiable on-chain path exists)**. Nest’s public HYPE Spring, if any, is a Nest-side airdrop/share — not a HyperLeaf “claim anytime” drip. Risk can be priced and transferred via the receipt token.

This is not a new idea. It is a missing piece of infrastructure that every staking ecosystem eventually needs. HyperLeaf builds it for HyperEVM — starting with the assets already there, expanding to every chain where demand exists.

---

## How It Works

```
User deposits staking asset (e.g. NEST)
            │
            ▼
HyperLeaf Vault locks asset into native staking (e.g. Nest veNEST → HEV)
            │
            ├── Auto-manages lock / HEV attach (no active user voting required)
            └── Yield to receipt holders arrives in two rails:
                        │
                        ├── Nest/HEV may compound under Nest rules (HyperLeaf share-price uplift not booked until verifiable accounting ships)
                        └── Nest public HYPE Spring airdrop share → via Nest (not a HyperLeaf “claim anytime” button)
            │
            ▼
User receives receipt token (e.g. hNEST) — freely tradable ERC-20
            │
            ├── Sell on any HyperEVM DEX for instant liquidity
            ├── Nest public HYPE Spring share (Nest UI/ABI; HyperLeaf does not currently wire a claim)
            └── Redeem via withdrawal queue (idle buffer / unlock windows — not instant 1:1)
```

Each asset is an isolated vault. One vault's risk never touches another.

---

> ⚠️ **Mainnet (HyperEVM 999) — capped open.** Deposits may be enabled subject to on-chain `depositCap` / pause. **Not yet externally audited.** Do not send funds you cannot lose. App: https://hyperleaf.finance/app/

## Supported Assets

HyperLeaf launches with one asset and expands incrementally. Each new vault is deployed, tested, and verified independently before launch.

| Asset | Receipt Token | Status | Underlying Protocol |
|-------|--------------|--------|-------------------|
| NEST | hNEST | 🟢 Live | Nest Exchange (HyperEVM) |
| RAM | hRAM | 🔵 Next | Ramses (HyperEVM) |
| HYBR | hHYBR | 🔵 Planned | Hybrix (HyperEVM) |
| More | — | 🔘 Roadmap | Multi-chain expansion |

New assets are selected based on: genuine staking yield, sufficient on-chain liquidity, and protocol security maturity. Meme assets without staking mechanics are not eligible.

---

## Architecture

HyperLeaf uses a **factory pattern**. Each supported asset has its own isolated vault contract deployed by a central factory. Vaults share no state. A vulnerability or failure in one vault cannot propagate to others.

```
HyperLeafFactory
├── NestVault → hNEST
├── RamVault  → hRAM
├── HybrVault → hHYBR
└── ...
```

**Every vault follows the same structure:**
- Accepts one input asset
- Locks into the asset's native staking protocol
- Issues one ERC-20 receipt token
- Keeper maintains vault ops (queue / idle / selective dettach); Nest HEV handles auto-vote / lock extension
- **No** user “auto-reinvest” button; **`recordCompound` is disabled** so HyperLeaf will not book unbacked NAV increases
- Maintains a withdrawal queue for native redemption (plus lean idle buffer)
- Protocol fee (if any) goes to `feeRecipient` from fee-configured streams — not marketed as liquid HYPE Spring inside HyperLeaf

**Receipt tokens are standard ERC-20 with ERC-2612 permit support.** They require no special handling to list on DEXs, use as collateral, or integrate into other protocols.

---

## Withdrawal

Two exit paths, always available:

**Instant — sell on DEX**
Receipt tokens trade on HyperEVM DEXs. Price is market-determined. During normal conditions this trades near NAV. During stress, discount widens — which is exactly the mechanism that allows risk to be transferred to willing buyers rather than trapped with unwilling holders.

**Queue — native redemption**
Call `requestWithdraw()`. Receipt token is burned immediately. Underlying asset is returned when the corresponding staking position naturally expires. No slippage. No discount. Time cost only.

The existence of the DEX exit is what makes the queue exit safe. Users who cannot wait sell to users who can. Both are better off than they would be with no market at all.

---

## Risk Disclosure

HyperLeaf does not eliminate staking risk. It makes staking risk liquid.

- **Lock risk**: underlying assets are staked and subject to the lock periods of their native protocols
- **Market risk**: receipt token price is set by the market and may trade below NAV
- **Smart contract risk**: contracts may contain bugs; **Not yet externally audited** — not a substitute for a third-party audit
- **Dependency risk**: vaults depend on the interfaces of their underlying staking protocols; upgrades to those protocols may require vault upgrades
- **Reward variability**: staking yield depends on Nest / underlying performance and is not guaranteed
- **Yield rails**: Nest/HEV may compound on Nest’s side; HyperLeaf share NAV is **not** auto-uplifted while `recordCompound` is disabled. Liquid HYPE from Nest’s **public HYPE Spring** is Nest-side airdrop/share — not a HyperLeaf wallet drip

Deposit caps are enforced during each vault's initial period and raised progressively as the vault matures.

---

## Contracts

Deployed on HyperEVM. Source verified via Sourcify (explorer listings may be partial).

| Contract        | Address (Mainnet 999)                        | Description                                |
| --------------- | -------------------------------------------- | ------------------------------------------ |
| `NestVault.sol` | `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` | NEST liquid staking vault                  |
| `HNest.sol`     | `0x2101621F51D7E05518D6680C62d04Ad47bC4e05D` | hNEST receipt token                        |
| `HevAdapter.sol`| `0xc89273ACB22a4e1df81A396FE0Bf6eD6E2CA6fD2` | Nest HEV attach adapter                    |
| `BaseVault.sol` | —                                            | Shared vault logic inherited by all vaults |
| `interfaces/`   | —                                            | External protocol interfaces               |
| `keeper/`       | —                                            | Weekly automation scripts                  |

Testnet (998) mock (internal only): NestVault `0x6f8d22C85e505eCA309635EA552f5067C026A2A9`, HNest `0xe86961EAF3CD4ED87497641fF32E55875aB7189f`.

---

## Development

```bash
git clone https://github.com/HyperLeafHQ/HyperLeaf
cd hyperleaf
npm install

# compile
npx hardhat compile

# test
npx hardhat test

# fork test against HyperEVM mainnet
npx hardhat test --network hardhat_fork
```

Read `DEV_REQUIREMENTS.md` before writing any code. The most critical pre-deployment step for each new vault is verifying the exact ABI of the underlying staking protocol on HyperEVM Explorer.

---

## Security review

| Vault | Kind | Status | Notes |
|-------|------|--------|--------|
| NestVault / hNEST | **Not yet externally audited** | Internal review docs may exist under `docs/` | **Not** a third-party audit. Do not describe the protocol as “audited.” |

Third-party audits, if commissioned later, will be disclosed explicitly with reports. Until then, assume unaudited smart-contract risk.

---

## Roadmap

**Phase 1 — HyperEVM Native**
Deploy hNEST, establish the factory pattern, prove the model. Expand to RAM and HYBR once hNEST is stable.

**Phase 2 — HyperEVM Ecosystem**
Cover every meaningful staking asset already inside HyperEVM. Build brand recognition as the default LST layer for HyperEVM-native protocols.

**Phase 3 — Multi-chain Expansion**
Bring assets from other chains into HyperEVM as liquid receipt tokens. Users stake on their home chain; their yield lives in HyperEVM.

**Phase 4 — Composability**
Integrate receipt tokens as collateral across HyperEVM lending and derivatives protocols. hNEST, hRAM, and others become first-class assets in the broader ecosystem.

---

## License

MIT
