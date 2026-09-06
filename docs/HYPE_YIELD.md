# Convert staking yield to HYPE

Users keep the locked principal. Newly accrued staking yield is sold for
**canonical HyperEVM HYPE** (WHYPE `0x555…555`). Protocol takes **1%**, holders
claim **99%**. No protocol fee on lock / unlock.

NEST is unchanged (already HYPE).

## Routes (keeper, not in the lockbox)

| Source | Harvest into | Bridge | Why |
| --- | --- | --- | --- |
| Solana (BONK / MET / JupSOL) | Wormhole HYPE `98sMhvDwXj1RQi5c5Mndm3vPe9cBqPrbLaufMXFNMh5g` | Wormhole Portal → HyperEVM WHYPE | Deep Jupiter books |
| Base (sKAITO airdrops, QUID, VIRTUAL) | Wormhole NTT HYPE `0x15D0e0c55a3E7eE67152aD7E89acf164253Ff68d` | Portal / Relay → WHYPE | Official NTT. **Not** cbHYPE (too thin) |
| BSC (BLUAI) | USDC, never the fake BSC “HYPE” | **Relay** intent, dest = HyperEVM WHYPE. Fallback: deBridge USDC then swap | Relay is one quote to WHYPE; deBridge if Relay has no fill |

sKAITO share growth: `pullYield` can take the extra sKAITO, but the keeper
**must not auto-sell** while Base sKAITO books are thin. Side-token airdrops yes.

## Contracts

1. Source lockbox: `setConvertYieldToHype(true)` + `setHarvester`. Redeem is 1:1.
   `pullYield(token, to)` sends only `balance - principal` (inner) or the full
   side-token balance. Principal cannot move.
2. HyperEVM `LeafHypeRewarder`: `notify(id, amount)` pulls WHYPE, 1% feeRecipient,
   99% `accHypePerShare`. `LeafOFT.setHypeRewarder` settles on transfer.
3. User: `claim(id, to)`.

## Deploy

```
OWNER=… FEE_RECIPIENT=… forge script script/lz/DeployHypeRewarder.s.sol \
  --rpc-url $HYPEREVM_RPC_URL --broadcast --private-key $PK

# per listing
cast send $OFT "setHypeRewarder(address,bytes32)" $REWARDER $ID
cast send $REWARDER "register(bytes32,address)" $ID $OFT
cast send $ADAPTER "setConvertYieldToHype(bool)" true
cast send $ADAPTER "setHarvester(address)" $KEEPER
```

`ID = keccak256(bytes("hkaito"))` (same as `AssetCatalog` ids).

## Keeper

`keeper/hypeYield.ts` — pull surplus, swap per table, `notify`. Weekly is enough.
Do not run a 24/7 VPS for minting; this is harvest-only.
