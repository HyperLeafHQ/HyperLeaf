# Solana program binary (hJitoSOL)

Read with [`GROK_BOT_MAINNET.md`](GROK_BOT_MAINNET.md) §5. This file is the
`.so` appendix. Do not start this until **batch 4 has passed**.

NCN / restaking is **out**. Wrap JitoSOL mint only. No extra airdrop path.

The lockbox **logic** is `solana/leaf-jito-rate` (`cargo test`). A mainnet
**`.so` is not produced in the architect sandbox** (host rustc only). Do not
install Agave there. Do not check in a hand-built `.so`.

## Machine

LayerZero Solana OApp **requires a verifiable Docker build**. Copy
`examples/oapp-solana`. Do not invent Endpoint remaining-accounts.

| Tool | Version |
| --- | --- |
| Rust | 1.84.1 |
| Solana CLI | 2.2.20 |
| Anchor | 0.31.1 |
| Docker | required (`anchor build -v`) |

## Commands

See GROK_BOT_MAINNET §5a. After deploy: init Store PDA, escrow ATA, harvest
ATA, ULN trio Labs + Horizen + Canary (Solana pubkeys in `LeafJitoPolicy`).
Print Store PDA. Then §5b on HyperEVM.

If the program disagrees with `cargo test --manifest-path solana/leaf-jito-rate/Cargo.toml`,
the program is wrong.
