# Grok bot — testnet scripts (not go-live)

**Cross-chain acceptance moved to mainnet.** HyperEVM testnet cannot run the real 2-of-3 DVN stack or the send/receive confirmation split.

Copy-paste for grok bot: **[`GROK_BOT_MAINNET.md`](GROK_BOT_MAINNET.md)**.

`script/lz/DeployTestnet*.s.sol` still exist for anvil / faucet UI. They revert on 8453/999/56. Do not skip `SetSecurityStack` on mainnet. Do not point `INNER_TOKEN` at live xSQUID / cbETH / BLUAI.

Old round locks (`TestnetCatalog` hxSQUID+hAVNT+hcbETH+BLUAI4Y) are historical. Live order is `MainnetBatches`:

0 canary → 1 hxsquid/havnt → 2 hcbeth/hgsoon/hswbera → 3 hsavax/hsethfi/hstkwausdc → 4 bluai4y/horder.
