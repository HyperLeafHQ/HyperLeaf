# leaf_jito — HyperLeaf hJitoSOL Solana OApp lockbox

LayerZero OApp (Anchor 0.31.1) that wraps **JitoSOL** and bridges shares to
HyperEVM as **hJitoSOL**. Lockbox math is owned by `leaf-jito-rate`
(`cargo test` is the spec — currently **25/25**). This crate is the on-chain runtime.

## Pins

| Item | Value |
| --- | --- |
| Rust | 1.84.1 |
| Solana CLI | 2.2.20 |
| Anchor | 0.31.1 |
| Mint | `J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn` |
| Pool | `Jito4APyf642JPZPx3hGc6WWJ8zPKtRbRs4P815Awbb` |
| EID | 30168 → 30367 |
| Store seed | `b"Store"` |

## Build (verifiable)

Docker required (`solanafoundation/anchor:v0.31.1`).

```bash
# from solana/leaf-jito
export LEAF_JITO_ID=$(solana-keygen pubkey ~/.secrets/hjitosol/leaf_jito-keypair.json)
mkdir -p target/deploy && cp ~/.secrets/hjitosol/leaf_jito-keypair.json target/deploy/
anchor build -v -e LEAF_JITO_ID=$LEAF_JITO_ID
```

Non-reproducible local build:

```bash
LEAF_JITO_ID=$LEAF_JITO_ID anchor build --no-idl
```

Spec tests (must stay green):

```bash
cargo test --manifest-path leaf-jito-rate/Cargo.toml
cargo test --manifest-path ../leaf-jito-rate/Cargo.toml
```

Do **not** commit a hand-built `.so`. Verifiable artifacts live under
`target/verifiable/` after `anchor build -v`.

## Instruction mapping (native 1-byte → Anchor 8-byte)

Native `leaf-jito-rate` uses 1-byte discriminators. Anchor uses 8-byte
sighashes. Runtime entrypoints:

| Native OP | Native name | Anchor ix |
| --- | --- | --- |
| 0 | Init | `init_store` |
| 1 | Lock | `lock` (+ LZ Endpoint send CPI) |
| 2 | HarvestRate | `harvest_rate` |
| 3 | HarvestOther | `harvest_other` |
| 4 | Halt | `halt` |
| 5 | LzReceive | `lz_receive` (executor only; `clear` via Endpoint) |

Also: `set_peer_config`, `quote_lock`, `lz_receive_types_v2`,
`lz_receive_types_info` (LZ OApp surface from `examples/oapp-solana`).

## Store layout

Anchor `Store` = 8-byte discriminator + LZ fields (`admin`,
`endpoint_program`, ATAs) + lockbox counters matching the 167-byte native
codec in `leaf-jito-rate::store` (`lockbox_encode()`).

## Security (#20) notes

- **LZ receive:** Endpoint `clear` CPI + peer PDA sender check + GUID/nonce
  (OApp primitives). No user `Unlock`.
- **Admin:** `halt` / `init_store` / `set_peer_config` gated to `store.admin`.
- **Rate source:** pool address + owner program + account type byte + mint.
- **HWM:** matches `leaf-jito-rate` (does **not** lower watermark on slash;
  recovery is net of loss). Flag for audit vs any older EVM wording in #20.
- **Trailing bytes:** bridge payload exact 96 bytes; native ix codec rejects
  trailing bytes in the spec crate.
- **Checked math:** lockbox uses checked paths via rate crate; token amounts
  use `try_into` with `MathOverflow`.

## Verifiable artifact (this PR)

```
program id:  E7UKM5BCAV5dbjuduDDnZXeQJ7muZ4xLCFd4XCBhzDax
Store PDA:   4gxkqrLhRF9q2n8hoPoSVekShiSNMoFR2ZXMx7XikxtW  (seed b"Store", bump 255)
.so sha256:  255bf44c211b1550cc05852bc633d6b7a5922330122ef70cdd0e7600735a72c5
```

Built with `anchor build -v` (Docker `solanafoundation/anchor:v0.31.1`).
IDL step may warn on host Cargo; the verifiable `.so` is the audit artifact.

**Not deployed. Not LIVE. For audit only.**
