# sKAITO wrap (Base -> HyperEVM hKAITO)

Only official sKAITO. No KAITO conversion. Redeem is instant sKAITO on Base.

Trusted relayer, not a light-client bridge. Keep depositCap small.

## Tokens

| Token | Chain | Address |
| ----- | ----- | ------- |
| sKAITO | Base (8453) | `0x548D3B444da39686d1a6F1544781d154e7cD1EF7` |
| hKAITO | HyperEVM (999) | deploy `src/wrap/HKaito.sol` |
| Vault | Base | deploy `src/wrap/SKaitoVault.sol` |

## Flow

1. User `approve` + `SKaitoVault.deposit(amount)` on Base.
2. Relayer sees `Deposited` and calls `HKaito.mint(user, amount, depositId)` on HyperEVM.
3. User trades hKAITO, or `HKaito.redeem(amount)`.
4. Relayer sees `RedeemRequested` and calls `SKaitoVault.release(user, amount, redeemId)` on Base.

Same EOA on both chains.

## Deploy

```
# Base
SKaitoVault(sKAITO, relayer, guardian, depositCap)

# HyperEVM
HKaito(relayer, guardian)
```

Owner, Guardian, Relayer must be three different keys. Relayer is a hot wallet on both chains.

## Relayer

- Watch Base `Deposited` then mint if `minted(depositId)` is false. Retry same id on failure.
- Watch HyperEVM `RedeemRequested` then release if `released(redeemId)` is false. `to` must be the burner.
- Never skimSurplus from the relayer key.
- Pause both contracts if the relayer key is lost.

Airdrops that land on the Base vault are protocol-owned until you snapshot hKAITO holders. Yapper identity does not follow traded hKAITO.
