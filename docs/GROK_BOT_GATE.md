# Grok bot — EpochHNestGate redeploy (HyperEVM mainnet)

You deploy. You do **not** reuse `0xB4C43e9cE08ff5540e0E240dB7784f47231d519B`.
That address is the **wrong binary** (`feat/nest-8d-withdraw-gate` @ `7cd3134`).
It is empty. Leave it. Frontend must not point at it.

Branch: **`feat/lz-oft-wrap`**. Pin **`36a6581` or later**. Must contain
`claimTranche` and `MAX_TRANCHES_PER_EPOCH`. If `git show HEAD:src/EpochHNestGate.sol`
has a 4-arg constructor or `userClaimableAt` and no `DepositTranche`, **STOP**.

This is **not** BATCH 0–5. Do not wait for Leaf Market / bluai4y.
Do **not** touch NestVault `0x4f6615…`. Do **not** deploy `LeafClaimFill`.

---

## Why the first deploy is rejected

| Live `0xB4C43…` (`7cd3134`) | Required (this wrap) |
| --- | --- |
| 4-arg ctor, no guardian | 5-arg ctor, guardian required |
| `userClaimableAt` max-merge (Luna P1-1) | independent `claimTranche` |
| `allocateHype(0)` seals `hypeFinal` | `allocateHype(0)` reverts; `finalizeHype` after `end+1d` |
| `rollEpoch` onlyKeeper; deposit does not auto-roll | permissionless `rollEpoch`; deposit auto-rolls |
| live `feeBps` at allocate | `feeBpsSnapshot` / `feeRecipientSnapshot` at open |
| `deposit+8d` only; epoch starts at deploy | `claimableAt = max(deposit+8d, Thursday epochEnd+30m)` |

---

## Addresses

| Role | Address |
| --- | --- |
| Vault (do not configure) | `0x4f6615761A772e10d7f802B1C29654ABD90fF30d` |
| WHYPE | `0x5555555555555555555555555555555555555555` |
| Owner | `0x24458f0bC44C4607172d1151Cd938012Be33156e` |
| Guardian | `0x12dF4528E7Cc3db07A509c966c6405b69A25Ef2e` |
| Keeper | `0xc321DD8826a30D8a6D973821a3dB7b8090955887` |
| feeRecipient | `0x76c8c4586F0a3d335CF7192eBbB4FE6Ed5Af3804` |

`OWNER` ≠ `GUARDIAN` ≠ `KEEPER`. `PRIVATE_KEY` is the hot wallet. Transfer
ownership out. Do not leave this bot as owner.

---

## Do

```
OWNER=0x24458f0bC44C4607172d1151Cd938012Be33156e \
GUARDIAN=0x12dF4528E7Cc3db07A509c966c6405b69A25Ef2e \
KEEPER=0xc321DD8826a30D8a6D973821a3dB7b8090955887 \
FEE_RECIPIENT=0x76c8c4586F0a3d335CF7192eBbB4FE6Ed5Af3804 \
forge script script/DeployEpochHNestGate.s.sol:DeployEpochHNestGate \
  --rpc-url hyperevm --broadcast --private-key $PRIVATE_KEY
```

Ctor is **5 args**: `(vault, WHYPE, keeper, guardian, feeRecipient)`.
A 4-arg `new EpochHNestGate` is the rejected binary. Revert the tx if you
compiled from `feat/nest-8d-withdraw-gate`.

---

## Verify before any UI

1. `chainid == 999`
2. `code` size is **not** the old 5724-byte gate
3. `gate.vault()` = live NestVault
4. `gate.hNest()` = `0x2101621F51D7E05518D6680C62d04Ad47bC4e05D`
5. `gate.nestToken()` = `0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035`
6. `gate.hypeToken()` = WHYPE
7. `gate.keeper()` / `guardian()` / `feeRecipient()` / `feeBps()==100`
8. `MAX_TRANCHES_PER_EPOCH()==32`
9. `HYPE_FINALIZE_DELAY()==86400`
10. `HNEST_MINT_DELAY()==691200`
11. `claimTranche` selector exists (`cast sig "claimTranche(uint256,uint256)"` in bytecode)
12. `userClaimableAt` must **not** exist (or revert). Tranche getter must exist.
13. `epochs(0)` has **feeBpsSnapshot=100** and **feeRecipientSnapshot=feeRecipient**
14. `epochs(0).end` = next **Thursday 00:00 UTC** (unix `ts/7days*7days + 7days`), not deploy+7d
15. NEST `allowance(gate, vault) == max`
16. `pendingOwner() == Owner`. Owner `acceptOwnership`. Bot must not remain owner.
17. Balances 0. Do **not** deposit user funds as smoke.

Dust smoke (your NEST only, tiny):

- `deposit` works
- second `deposit` 1 day later creates `trancheCount==2` with **different** `claimableAt`
- `allocateHype(0, 0)` reverts
- after epoch end, a **non-keeper** can `rollEpoch`
- `guardian` can `pause`; owner `unpause`

PR comment:

1. Old gate `0xB4C43…` abandoned (empty).
2. New address + tx + `git rev-parse HEAD`.
3. Confirm `claimTranche` + Thursday `epochEnd` + `feeBpsSnapshot`.
4. Frontend: new deposits that opt into Gate use **this** address only.
5. Do **not** advertise weekly Nest HYPE until a real harvest `allocateHype` is non-zero.

---

## Do not

- Deploy from `feat/nest-8d-withdraw-gate` / PR #22 / `7cd3134`
- `setDepositGate` on live vault (no such function)
- Send users to `0xB4C43e9cE08ff5540e0E240dB7784f47231d519B`
- `setRewarder` / Leaf Market changes / NestVault config
- Protocol bid / “hNEST is always 8-day locked”
- Leave bot as owner
