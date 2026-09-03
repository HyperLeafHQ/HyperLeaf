# HyperLeaf

**Every asset deserves liquidity. Every yield deserves a market.**

HyperLeaf is a multi-chain liquid staking protocol built on HyperEVM. Deposit any supported staking asset, receive a freely tradable ERC-20 receipt token, and keep earning rewards — without waiting for lock periods to expire.

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

A user who deposits into HyperLeaf does not give up yield. They gain an exit. The underlying position continues earning. The receipt token can be sold, used as collateral, or held to accumulate rewards. Risk is no longer locked in. It can be priced, traded, and transferred to whoever is willing to hold it.

This is not a new idea. It is a missing piece of infrastructure that every staking ecosystem eventually needs. HyperLeaf builds it for HyperEVM — starting with the assets already there, expanding to every chain where demand exists.

---

## How It Works

```
User deposits staking asset (e.g. NEST)
            │
            ▼
HyperLeaf Vault locks asset into native staking protocol
            │
            ├── Auto-manages staking (voting, compounding, claiming)
            └── Distributes rewards to receipt token holders
                        │
                        ├── Auto-compounded yield → receipt token NAV increases
                        └── Protocol reward tokens → claimable by holders anytime
            │
            ▼
User receives receipt token (e.g. hNEST) — freely tradable ERC-20
            │
            ├── Sell on any HyperEVM DEX for instant liquidity
            ├── Claim accumulated reward tokens anytime
            └── Redeem via withdrawal queue when staking position expires
```

Each asset is an isolated vault. One vault's risk never touches another.

---

> ⚠️ **Testnet only.** HyperLeaf is currently deployed on HyperEVM testnet. 
> Mainnet launch pending audit. Do not send real funds.

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
- Runs a weekly keeper for reward harvesting and compounding
- Maintains a withdrawal queue for native redemption
- Takes 1% of reward token distributions as protocol fee

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
- **Smart contract risk**: each vault is audited before launch; audit reports are published in this repository
- **Dependency risk**: vaults depend on the interfaces of their underlying staking protocols; upgrades to those protocols may require vault upgrades
- **Reward variability**: staking rewards depend on underlying protocol performance and are not guaranteed

Deposit caps are enforced during each vault's initial period and raised progressively as the vault matures.

---

## Contracts

Deployed on HyperEVM. All source code verified on HyperEVM Explorer.

| Contract | Address (Testnet) | Description |
|----------|------------------|-------------|
| `NestVault.sol` | 0x6f8d22C8... | NEST liquid staking vault |
| `HNest.sol` | 0xe86961EA... | hNEST receipt token |
| `NestVault.sol` | NEST liquid staking vault |
| `HNest.sol` | hNEST receipt token |
| `BaseVault.sol` | Shared vault logic inherited by all vaults |
| `interfaces/` | External protocol interfaces |
| `keeper/` | Weekly automation scripts |

---

## Development

```bash
git clone git clone https://github.com/HyperLeafHQ/hyperleaf
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

## Audits

| Vault | Auditor | Status | Report |
|-------|---------|--------|--------|
| NestVault | TBD | Pending | — |
> Mainnet deployment pending audit completion.

Audit reports are published in `/audits` upon completion. No vault launches without a completed audit.

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
