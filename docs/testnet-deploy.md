# Testnet deploy (HyperEVM 998)

Every listing in `listings/catalog.json` can be deployed with the same two scripts.
Testnet **always mints a mock inner token** unless you set `INNER_TOKEN`.
Do **not** point testnet adapters at mainnet sKAITO / VIRTUAL / BLUAI.

HyperEVM testnet LayerZero DVNs are only **LayerZero Labs + P2P**. Skip
`SetSecurityStack` on testnet (that script is the mainnet 2-of-3). Default
endpoint config is enough to move test messages.

## Env

```
OWNER=0x...
GUARDIAN=0x...          # different EOA
FEE_RECIPIENT=0x...     # protocol 1%
PRIVATE_KEY=0x...
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BSC_TESTNET_RPC_URL=https://bsc-testnet-rpc.publicnode.com
HYPEREVM_TESTNET_RPC_URL=https://rpc.hyperliquid-testnet.xyz/evm
```

Need gas: Base Sepolia ETH, BSC testnet BNB, HyperEVM testnet HYPE.

Grok bot: follow **`docs/GROK_BOT_TESTNET.md`** (hxSQUID then hcbETH, then bluai4y). That file is the copy-paste. This page is the generic catalog.

## Per asset

| ASSET | Kind | Source testnet | Dest |
| --- | --- | --- | --- |
| `hkaito` | L | Base Sepolia | HyperEVM 998 |
| `hxsquid` | L | Base Sepolia | 998 |
| `hcbeth` | L | Base Sepolia | 998 |
| `hsavax` | L | Base Sepolia mock (Fuji later) | 998 |
| `hvirtualmax` | C1 | Base Sepolia | 998 |
| `bluai4y` | C1 | BSC testnet | 998 |
| `bonk12m` | C1 | Base Sepolia mock | 998 |
| `hmet` | C2 | Base Sepolia mock | 998 |
| `hshmon` | L | Base Sepolia mock | 998 |
| `hgsoon` | L | BSC testnet 97 | 998 |
| `hswbera` | L | Base Sepolia mock (Bepolia LZ empty) | 998 |

hNEST is **not** LZ. It stays on HyperEVM (`NestVault`).

### 1. Source

Base-sepolia assets:

```
ASSET=hkaito OWNER=... GUARDIAN=... FEE_RECIPIENT=... \
forge script script/lz/DeployTestnetSource.s.sol:DeployTestnetSource \
  --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --private-key $PRIVATE_KEY
```

BLUAI:

```
ASSET=bluai4y ... \
forge script script/lz/DeployTestnetSource.s.sol:DeployTestnetSource \
  --rpc-url $BSC_TESTNET_RPC_URL --broadcast --private-key $PRIVATE_KEY
```

Log: `MockInner`, `LeafOFTAdapter` | `LeafInboundLockbox` | `LeafRedeemQueue`.

### 2. Dest (HyperEVM testnet)

```
ASSET=hkaito OWNER=... GUARDIAN=... \
forge script script/lz/DeployTestnetDest.s.sol:DeployTestnetDest \
  --rpc-url $HYPEREVM_TESTNET_RPC_URL --broadcast --private-key $PRIVATE_KEY
```

Log: `LeafOFT` or `LeafClosedOFT`, plus a `LeafWrapRegistry` the first time.

### 3. Wire both ways

Source → dest:

```
OAPP=<source> PEER=<oft> REMOTE_EID=40362 \
forge script script/lz/WirePeers.s.sol:WirePeers \
  --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --private-key $PRIVATE_KEY
```

Dest → source (Base Sepolia EID 40245, BSC testnet 40102):

```
OAPP=<oft> PEER=<source> REMOTE_EID=40245 \
forge script script/lz/WirePeers.s.sol:WirePeers \
  --rpc-url $HYPEREVM_TESTNET_RPC_URL --broadcast --private-key $PRIVATE_KEY
```

### 4. Smoke

1. MockInner `mint` already sent 1e6 to OWNER.
2. `approve` source, `sendTo{value: lzFee}(40362, yourHyperEvmAddr, amount)`.
3. Wait LZ deliver; dest OFT balance increases.
4. L / C2: dest `sendTo` back; C1 `send` reverts `ExitViaMarketOnly`.
5. C2: after 21 days `claim(ticketId)` on source.

Quote native fee with `source.quote(eid, payload, options, false)` or overpay ~0.01 native.

## What is still not production

| Asset | Testnet | Mainnet |
| --- | --- | --- |
| hKAITO, hxSQUID, hcbETH, hVIRTUALMAX, BLUAI4Y | real LZ path, mock inner | same contracts, real inner, SetSecurityStack |
| BONK12M, hMET | mock C1/C2 on Base Sepolia | needs Solana lockbox |
| hsAVAX | mock on Base Sepolia | Avalanche + LZ 30106 |
| hshMON | mock | Monad LZ |
| JupSOL / BTCFi / SUI / XPL | not in this drop | later |

Fee: 1% of newly accrued inner yield only. No protocol fee on lock/unlock.
