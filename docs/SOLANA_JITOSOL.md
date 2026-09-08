# hJitoSOL — first Solana listing

Not this Grok-bot pass (batches 0–4 stay EVM). Dest OFT can be deployed with `BATCH=5 ASSET=hjitosol`. Source is a **new Solana program**, not `LeafOFTAdapter`.

## What we wrap

| | |
| --- | --- |
| Mint | `J1toso1uCk3RLmjorhTtrVwY9HJ7X8V9yYac6Y7kGCPn` (JitoSOL, 9 dp) |
| Pool | `Jito4APyf642JPZPx3hGc6WWJ8zPKtRbRs4P815Awbb` |
| Stake pool program | `SPoo1Ku8WFXoNDMHPsrGSTSG1Y47rzgn41SLUNakuHy` — **forbidden CPI** |
| Rate | `total_lamports * 1e18 / pool_token_supply` (must `pool_mint == JitoSOL`) |
| Dest | HyperEVM `LeafOFT` `hJitoSOL`, 18 dp. `shares = atoms * 1e9` |
| LZ | eid **30168** → 30367. Receive confirmations **32**. Peer is a **32-byte PDA** (`WireSolanaPeer`, never `WirePeers` address) |

Never wrap SOL. Never `depositSol` / `withdrawSol` / `depositStake`. User who wants SOL: unwrap hJitoSOL → JitoSOL, then Jito.

## 1% skim (same as hcbETH)

JitoSOL quantity does not grow. SOL-per-token does. Math is `LeafJitoRate` / `solana/leaf-jito-rate` (must stay equal):

```
surplus = lastAccounted * (rate - lastRate) / rate
fee     = 1% of surplus   → harvest ATA → later WHYPE
99%     stays as remaining JitoSOL in the PDA
slash   → watermark down, fee 0
donation JitoSOL → not lastAccounted, not yield
```

Wrap and redeem settle the 1% first. Redeem is pro-rata remaining atoms, not 1:1 after a harvest.

## Message

Opaque bytes LeafOFT already decodes:

```
abi.encode(listingTag, bytes32(to), uint256 shares)
listingTag = keccak256("hjitosol")
```

96 bytes. Solana `lz_send` payload **must** be this ABI encoding, not Borsh.

## Program shape (next code, this crate is the math)

PDA escrow token account holds JitoSOL. Instructions: `lock` (transfer in + lzSend shares), `unlock` (lzReceive burn + transfer out), `harvest` (read pool, book fee, transfer fee atoms to harvest ATA). Admin: peer, tag, caps, halt. Upgrade authority: HyperLeaf multisig, not a hot key.

`cargo test --manifest-path solana/leaf-jito-rate/Cargo.toml` is the rate lock.

## Do not

- Vanilla LZ OFT Adapter 1:1 without harvest (protocol take would be 0)
- bnSOL, mSOL, jupSOL this listing
- Point `INNER_TOKEN` at anything on Base
- Open a second Solana source eid into the same dest OFT
