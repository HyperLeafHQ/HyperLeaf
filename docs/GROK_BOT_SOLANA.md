# Solana program binary (hJitoSOL)

The lockbox **logic** is in `solana/leaf-jito-rate` (`cargo test` on any
Rust). A mainnet **`.so` is not produced in the architect sandbox.** That
machine has host `rustc` only — no Agave platform-tools, no `cargo-build-sbf`,
no Docker. Do not try to install those there. Do not check in a hand-built
`.so`.

NCN / restaking is **out**. Wrap JitoSOL mint only. No extra airdrop path.

## What actually produces the binary

LayerZero Solana OApp **requires a verifiable Docker build**. Copy their
template, do not invent Endpoint remaining-accounts.

Pinned to LZ `examples/oapp-solana` (do not float):

| Tool | Version |
| --- | --- |
| Rust | 1.84.1 (LZ pin — not the sandbox 1.98) |
| Solana CLI | 2.2.20 |
| Anchor | 0.31.1 |
| Docker | required (`anchor build -v`) |
| Node | whatever `devtools` example uses |

```
# 1. Machine with Docker. Not the architect sandbox.
sh -c "$(curl -sSfL https://release.anza.xyz/v2.2.20/install)"
cargo install --git https://github.com/coral-xyz/anchor avm --locked
avm install 0.31.1 && avm use 0.31.1

# 2. Program id
solana-keygen new -o solana/target/deploy/leaf_jito_lockbox-keypair.json
anchor keys sync   # program id = that pubkey

# 3. Verifiable .so (this is the binary)
cd <lz oapp-solana fork with our Store/lock/harvest wired>
anchor build -v -e MYOAPP_ID=<PROGRAM_ID>
# → target/verifiable/leaf_jito_lockbox.so

# 4. Mainnet deploy
solana program deploy \
  --program-id solana/target/deploy/leaf_jito_lockbox-keypair.json \
  target/verifiable/leaf_jito_lockbox.so \
  -u mainnet-beta

# 5. Init Store PDA, create JitoSOL escrow ATA, set ULN
#    Labs + Horizen + Canary (Solana pubkeys). Never Nethermind.
#    dest peer = HyperEVM LeafOFT, 20-byte left-padded.

# 6. Then EVM batch 5: DeployOFT → WireSolanaPeer PEER=$STORE_PDA
#    → SetSecurityStack → ConfigureJitoDest
```

`cargo-build-sbf` without Docker is **not** the LZ path. Use `anchor build -v`.

## What the .so must do (already specified)

`solana/leaf-jito-rate` is the spec. The OApp processor must call it 1:1:

- `Lock` — harvest fee to harvest ATA, pull JitoSOL into escrow ATA, LZ send
  96-byte `abi.encode(tag, evm_to, shares)` to eid 30367
- `HarvestRate` — same fee move, no mint
- `LzReceive` only after dest burn — pay remaining atoms, never whole ATA
- No CPI to stake pool / interceptor / vault / restaking
- Peer freeze, listing tag `keccak256("hjitosol")`

If the program disagrees with `cargo test -p leaf-jito-rate`, the program is
wrong.

## Split of work

| Who | Does |
| --- | --- |
| This repo | Math, cash invariant, Store layout, dest OFT, DVN, docs |
| Grok bot (Docker machine) | `anchor build -v`, deploy `.so`, init Store, print Store PDA |
| Architect sandbox | **Never** `solana program deploy` |
