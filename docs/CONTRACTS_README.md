# hNEST MVP

forge test; see src/config/HyperEVMAddresses.sol

## Risks
HEV ABI unverified; exit delays; hNEST discount; EOA custody possible; feeBps; no MEGAHYPE.
风险: ABI未核实; 退出延迟; 折价; 可能EOA托管; 无MEGAHYPE。

## HEV ABI TODOs
1. Voter.attachManagedNFT(tokenId,1)
2. Voter.dettachManagedNFT spelling
3. Claim HYPE via Virtual Rewarder / VeNestDistributor
4. NFT transfer before attach?
5. Fork tests
6. Do not invent MEGAHYPE

## Pause / guardian (emergency controls)

- `guardian` (or `owner`) can `pause()` — blocks both `deposit` and `requestWithdraw`.
- Only `owner` can `unpause()` — guardian and keeper cannot (prevents hot-wallet/keeper unpause hijack).
- Keeper cannot pause or unpause.
- `setGuardian(address)` is `onlyOwner`; `address(0)` disables the guardian role.
- **Required before mainnet:** run a testnet pause drill (guardian pause → verify deposit/withdraw blocked → owner unpause → verify restored).
