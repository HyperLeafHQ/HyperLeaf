# Nest HEV HyperEVM Mainnet ABI Probe

**Date:** 2026-09-03 (Asia/Shanghai, UTC+8)  
**RPC:** `https://rpc.hyperliquid.xyz/evm` (chainId **999**)  
**Mode:** read-only (`eth_call` / `cast call` / bytecode PUSH4 / Sourcify).  
**No transactions broadcast. No NEST/HYPE spent. No private keys.**

Verified ABIs: `hnest/abi/mainnet/*.abi.json`.

---

## 1. Explorer / Sourcify status

| Source | Result |
|--------|--------|
| `api.hyperevmscan.io` V1 `getabi` / `getsourcecode` | **Deprecated** — `NOTOK`: switch to Etherscan API V2 |
| `api.etherscan.io/v2/api?chainid=999` | Requires API key (`Missing/Invalid API Key`); not used |
| Nest docs [`7.4-contracts`](https://docs.usenest.xyz/protocol-and-security/7.4-contracts.md) | Proxy + implementation address table (Core / factory) |
| Sourcify `chainId=999` | **Match** for Voter proxy, HEV proxy, and all listed impls **except** live VirtualRewarder impl `0x7ea6…e8cb` (404). Nest-doc SingelTokenVirtualRewarder impl `0xAF24…69DF` **is** verified and ABI-matches live views |

HyperEVMScan UI: Voter is TransparentUpgradeableProxy → current impl `0x2d70695c…677C1` (`VoterUpgradeableV2`).

---

## 2. Addresses, proxies, implementations

| Role | Proxy / address | Code bytes | EIP-1967 impl | Sourcify FQN |
|------|-----------------|------------|---------------|--------------|
| Voter | `0x566bdc5444fd5fe5d93ec379Bd66eC861ddbA901` | 2430 | `0x2d70695c2f32c6b692370318436ef18d5c4677c1` | `VoterUpgradeableV2` |
| veNEST | `0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074` | 2430 | `0xf70526a0089fdc334814c3498ca1ba30c25aba91` | `VotingEscrowUpgradeableV2` |
| ManagedNFTManager | `0x843d31e601b38F7207864457f0fB38E14441E792` | 2430 | `0x481f9d30a70a90f6b50e4d1052323a8e79802972` | `ManagedNFTManagerUpgradeable` |
| HEV strategy | `0x96F7b8BA7580d3E510B0Fb3F0E135a743d8eb17a` | 631 | `0x321ff9470cbb26674882c86a25f5470e48d280cf` | `CompoundVeNESTManagedNFTStrategyUpgradeable` (proxy: `StrategyProxy`) |
| VirtualRewarder | `0x148405ab9F58AC790CC6cA518077deD1E6E04829` | 631 | `0x7ea6ecbb533cb34aca1ca427cf60bf05caa3e8cb` | Unverified; ABI = `SingelTokenVirtualRewarderUpgradeable` |
| VeNestDistributor | `0x22350F14c6ee70992f1bbc7498e4C291B8B7682f` | 2430 | `0x6d87bad7b75499b84e3e28e618b43840f56acd9a` | `VeNestDistributorUpgradeable` |

Shared NEST token: `0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035`.

---

## 3. Live wiring views (confirmed)

| Call | Result |
|------|--------|
| `HEV.name()` | `"HYPE Engine Vault"` |
| `HEV.description()` | compounds fees into veNEST; mentions exclusive **MEGAHYPE** (not launched) |
| `HEV.managedTokenId()` | **1** |
| `HEV.virtualRewarder()` | VirtualRewarder above |
| `HEV.voter()` / `votingEscrow()` / `nest()` | Voter / veNEST / NEST |
| `HEV.getBuybackTargetToken()` | NEST |
| `HEV.totalSupply()` | equals VR `totalSupply()` (~2.96e26) |
| `HEV.detachmentLockDuration()` | `345600` (4 days) |
| `veNEST.ownerOf(1)` | HEV strategy |
| `ManagedNFTManager.isManagedNFT(1)` | `true` |
| `ManagedNFTManager.managedTokensInfo(1)` | `(true, false, 0x0E07A5efa3…FF20482)` |
| Sample attached NFT `100` | `isAttachedNFT=true`, managedId=`1`, `getLockedRewardsBalance(100)` = VR `calculateAvailableRewardsAmount(100)` (~3.53e22) |
| `VR.strategy()` | HEV strategy |
| `Voter.managedNFTManager()` | ManagedNFTManager |

---

## 4. Requested selector probe matrix

Method: `cast sig` + PUSH4 (`0x63` + selector) scan of **implementation** bytecode, plus `eth_call` on proxies.

Columns: Voter | veNEST | ManagedNFTManager | HEV | VirtualRewarder | VeNestDistributor  
`Y` = PUSH4 present on that impl; `.` = absent.

| Signature | Selector | V | ve | M | H | VR | D | Notes |
|-----------|----------|---|----|---|---|----|---|-------|
| `attachManagedNFT(uint256,uint256)` | `0x52376512` | . | . | . | . | . | . | **Unknown / absent everywhere** (`cast 4byte` unknown) |
| `attachManagedNFT(uint256)` | `0x4b985845` | . | . | . | **Y** | . | . | HEV **admin** bind of managed id — **not** user entry |
| `dettachManagedNFT(uint256)` | `0xfdfb1f8d` | . | . | . | . | . | . | **Unknown** (wrong name) |
| `detachManagedNFT(uint256)` | `0x1c59efad` | . | . | . | . | . | . | **Unknown** |
| `createLock(uint256,uint256)` | `0xb52c05fe` | . | . | . | . | . | . | **Missing** on veNEST — use `createLockFor(...)` |
| `getReward(uint256)` | `0x1c4b774b` | . | . | . | . | . | . | **Missing** |
| `getReward(address)` | `0xc00007b0` | . | . | . | . | . | . | **Missing** (adapter stub must not rely on this) |
| `claim()` | `0x4e71d92d` | . | . | . | . | . | . | **Missing** |
| `earned(uint256)` / `earned(address)` | `0x4d6ed8c4` / `0x008cc262` | . | . | . | . | . | . | **Missing** |
| `managedTokenId()` | `0xb0dfa498` | . | . | . | **Y** | . | . | HEV view → `1` |
| `name()` | `0x06fdde03` | . | **Y** | . | **Y** | . | . | veNEST `"veNest"`; HEV `"HYPE Engine Vault"` |

Wrong-name `eth_call` on Voter for `attachManagedNFT` / `dettachManagedNFT` / `detachManagedNFT` / `createLock` / `getReward` / `claim` / `earned` / `managedTokenId` / `name` → empty/`execution reverted` (missing selector).

### Confirmed Nest names (use these)

| Sig | Selector | Where | Live eth_call evidence |
|-----|----------|-------|------------------------|
| `attachToManagedNFT(uint256,uint256)` | `0xca82240d` | **Voter** | Typed revert `IncorrectUserNFT` (`0xb97b4fe2`) for tokenId=1 |
| `dettachFromManagedNFT(uint256)` | `0x12dd7200` | **Voter** | Typed revert `NotAttached` (`0xd6e7efb0`) |
| `createLockFor(uint256,uint256,address,bool,bool,uint256)` | `0x42c15c87` | **veNEST** | Present in Sourcify ABI |
| `getAttachedManagedTokenId(uint256)` / `isAttachedNFT(uint256)` | `0x1e60c38b` / `0x3b83245a` | **ManagedNFTManager** | Views OK |
| `onAttachToManagedNFT` / `onDettachFromManagedNFT` | — | Manager / veNEST | Voter-only / manager-only callbacks |
| `harvest(uint256)` | `0xddc63262` | **VirtualRewarder** | Typed revert `AccessDenied` (`0x4ca88867`) for EOA |
| `calculateAvailableRewardsAmount(uint256)` | `0x63db9f33` | **VirtualRewarder** | View success |
| `getLockedRewardsBalance(uint256)` | `0xed4ec0c2` | **HEV** | = VR calculateAvailable… |
| `claimRewards(address[])` | `0xf9f031df` | Voter / HEV | Gauge/bribe operator path — not per-user HYPE claim |
| `distributeVeNest(string,(address,bool,uint256,uint256,uint256)[])` | `0xf0407443` | VeNestDistributor | **Admin airdrop** — not user claim |

`cast 4byte` note: several Nest-specific selectors (`attachToManagedNFT`, `dettachFromManagedNFT`, `dettachManagedNFT`, …) are **unknown** in the public 4byte directory; presence was confirmed via Sourcify ABI + bytecode + typed reverts.

---

## 5. Semantics (attach / rewards / claim)

### User entry / exit (HEV)

1. Caller must be veNEST `ownerOf` or `isApprovedOrOwner` for `tokenId` (**contracts OK** if approved/owning).
2. **Entry:** `Voter.attachToManagedNFT(tokenId, 1)` → Manager `onAttachToManagedNFT` → HEV `onAttach` → VR `deposit(tokenId, userBalance)`.
3. **Exit:** `Voter.dettachFromManagedNFT(tokenId)` → Manager → HEV `onDettach` → VR `withdraw` + **`harvest(tokenId)`** (strategy-gated) → locked rewards returned onto user NFT.
4. HEV `attachManagedNFT(uint256)` is **onlyAdmin** strategy setup (bind managed NFT owned by strategy), **not** the deposit path.
5. Detach subject to vote delay / vote window / `dettachLockWindowInfo` / detachment lock duration.

### Accrual unit

- Strategy buyback target = **NEST**. VR pending share is NEST-denominated (compounded into managed veNEST), **not** a public ERC20 HYPE `getReward(address)`.
- `HEV.description()` advertises MEGAHYPE exclusivity; **MEGAHYPE not launched** — do not invent claim paths.
- **VeNestDistributor** mints/distributes veNEST via admin `distributeVeNest` — omit from user HYPE claim.

---

## 6. Recommended adapter / interface changes

### Must-fix (confirmed)

| Current hypothesis | Confirmed live | Action |
|--------------------|----------------|--------|
| `Voter.attachManagedNFT(tokenId, mid)` | `attachToManagedNFT(tokenId, mid)` `0xca82240d` | Rename in `IVoter` / `HevAdapter.depositVeNFT` |
| `Voter.dettachManagedNFT(tokenId)` | `dettachFromManagedNFT(tokenId)` `0x12dd7200` | Rename (keep double-**t** `dettach`, add `From`) |
| `lastVoted(tokenId)` | `lastVotedTimestamps(tokenId)` | Rename if used |
| `veNEST.createLock(a,b)` | `createLockFor(a,b,to,bool,bool,uint256)` | Update `IVotingEscrow` |
| `veNEST.locked(tokenId)` | `getNftState` / `nftStates` | Replace struct reader |
| `IVirtualRewarder.getReward(address)` / `earned(address)` | **Absent** | Remove; pending via `getLockedRewardsBalance` / `calculateAvailableRewardsAmount` |
| Claim via VeNestDistributor | Not a claim surface | Drop from claim path |

### Claim / pending redesign

```solidity
interface IHevStrategyViews {
    function managedTokenId() external view returns (uint256);
    function virtualRewarder() external view returns (address);
    function getLockedRewardsBalance(uint256 tokenId) external view returns (uint256);
    function balanceOf(uint256 tokenId) external view returns (uint256);
}

interface ISingelTokenVirtualRewarder {
    function balanceOf(uint256 tokenId) external view returns (uint256);
    function calculateAvailableRewardsAmount(uint256 tokenId) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function strategy() external view returns (address);
    // harvest/deposit/withdraw/notifyRewardAmount — strategy-only (AccessDenied otherwise)
}
```

- Prefer rename `pendingHype` → `pendingLockedRewards` (NEST) until Nest publishes a real HYPE/MEGAHYPE claim ABI.
- Keep `claimHype` as balance-sweep placeholder only; **do not** low-level `getReward(address)` on VR.
- Before live deposits: vault/adapter ownership **or** approval on veNEST; test attach/detach on a dedicated NFT; respect detach lock window.

### Do not call in HEV mode

- `vote` / `increase_unlock_time` on user NFT while attached (managed NFT votes; permanent lock common).

---

## 7. Remaining unknowns

1. Public **HYPE / MEGAHYPE** claim surface (none found on VR / HEV / Distributor).
2. Live VirtualRewarder **source** unverified on Sourcify/HyperEVMScan (ABI confirmed via Nest SingelToken interface + eth_call).
3. Product choice: adapter holds NFT vs vault holds + approves.
4. Full VR checkpoint / `tokensInfo` layout beyond balance + available rewards.
5. HyperEVMScan API V2 key not configured in repo (`.env.example` placeholders empty).

---

## 8. Probe artifacts

- `hnest/docs/HEV_ABI_PROBE.md` (this file)
- `hnest/abi/mainnet/{Voter,VotingEscrow,ManagedNFTManager,HEV_strategy,VirtualRewarder,VeNestDistributor}.abi.json`
- `src/interfaces/IVotingEscrow.sol`, `IVirtualRewarder.sol`, `IHevStrategy.sol`
- `src/NestVault.sol`, `src/HevAdapter.sol`, mocks, `test/HevFork.t.sol`
- `docs/FORK_SIM.md` (createLockFor flags + post-dettach lock reset)
- Default `forge test` excludes fork (`no_match_path`); use `FOUNDRY_PROFILE=fork`


---

## 9. Fork claim / attach simulation (2026-09-03)

**Mode:** `forge test --match-contract HevForkTest` against `https://rpc.hyperliquid.xyz/evm`. No broadcast. Skips if RPC down.

### 9.1 createLock API (veNEST)

| Call | Fork result |
|------|-------------|
| `createLock(uint256,uint256)` | **MISSING** (empty revert) |
| `createLockFor(amount, lockDuration, to, shouldBoosted, withPermanentLock, managedTokenIdForAttach)` | **EXISTS** — reverts `ERC20: insufficient allowance` without NEST pull; with `deal`+approve can mint |

**Vault wiring choice (NestVault.deposit):**
- `to_ = address(this)` (vault owns NFT)
- `shouldBoosted_ = false` — boost path not productized / risk of unexpected fee routes
- `withPermanentLock_ = false` — preserve timed unlock + withdraw-queue path
- `managedTokenIdForAttach_ = 1` (HEV) — **atomic lock+attach**; HevAdapter.depositVeNFT only calls `attachToManagedNFT` if `getNftState.isAttached == false`

### 9.2 Contract attach after approve

- Auth gate is veNEST `isApprovedOrOwner` (contracts OK).
- Fork test `AttachCaller` + `approve` → `Voter.attachToManagedNFT(tokenId, 1)` exercises the path (may still revert on detach/vote window for a live NFT; selector + auth confirmed).
- Atomic `createLockFor(..., managedId=1)` preferred for vault deposits.

### 9.3 Claim / pending surfaces

| Call | Result |
|------|--------|
| `HEV.getLockedRewardsBalance(tokenId)` | **EXISTS** view — equals `VR.calculateAvailableRewardsAmount(tokenId)` (NEST share) |
| `HEV.claimRewards(address[] gauges)` | **EXISTS** — empty array no-op success for any caller; claims **managed NFT** gauge rewards (operator), **not** per-user HYPE |
| `HEV.claimBribes(address[],address[][])` | **EXISTS** — same operator/managed-NFT semantics |
| `VR.harvest(uint256)` | **EXISTS** — `AccessDenied` for non-strategy |
| `VR.getReward(address)` | **MISSING** |

**HevAdapter claim stubs updated only where confirmed:**
- `pendingHype(tokenId)` → `HEV.getLockedRewardsBalance(tokenId)` (NEST-denominated share; name retained for vault ABI stability)
- `claimHype` → still **no** `getReward` / no user HYPE pull; only forwards stray HYPE ERC20 balance on adapter (usually 0). Liquid HYPE Spring / MEGAHYPE claim remains blocked pending Nest ABI.

### 9.4 Remaining blockers before real NEST deposit

1. **No liquid HYPE user claim** — pending is locked NEST share until dettach/compound; MEGAHYPE not launched.
2. **Detach lock window** — `dettachFromManagedNFT` / strategy detachment duration can block withdraw-queue unlock timing.
3. **HyperEVM block gas** — NestVault+HNest create must stay split (pre-deploy HNest); already handled.
4. **End-to-end fork of NestVault.deposit** with real NEST still needs a funded fork whale + full adapter/voter wiring rehearsal (this pass documented attach+claim only).
5. **Boost / permanent lock** — deliberately left `false`; revisit only with Nest product sign-off.
6. **Post-dettach lock reset** — live `onDettachFromManagedNFT` sets user lock `end = maxUnlockTimestamp()` (now+26w), wiping the original timed end. Withdraw-queue liquidity needs an idle NEST buffer and/or acceptance of ~26w post-detach delay. See `docs/FORK_SIM.md` §3.
7. **Attached state zeroes amount+end** — unlock eligibility cannot be read from `getNftState` while attached; NestVault detaches when withdraw queue needs liquidity (subject to vote/detach windows).
