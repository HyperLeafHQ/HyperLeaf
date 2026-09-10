# PYUSD — not an LST. Do not treat like JitoSOL

Verified 2026-09-10.

PYUSD is a **1:1 dollar**. PayPal/Paxos pay **0** native yield. [Paxos repo](https://github.com/paxosglobal/pyusd-contract): proxy `0x6c3ea9036406852006290770BEdFcAbA0e23A0e8`. Live ETH supply ~1.70B (6 dp).

| Chain | Token | |
| --- | --- | --- |
| Ethereum | ERC-20 above | Already wrapable with `LeafOFTAdapter`. Captures **0**. |
| Solana | SPL `2b1kV6DkPAnxd5ixfnxCpjxmKwqjjaYmCZfHsFu24GXo` (Token-2022) | Still a dollar. Needs the Solana lockbox **and** still 0 yield. |
| Arbitrum / Stellar | native issuance | Same. |

Spark `spPYUSD` `0x8012…d354`: Sky savings wrapper. Live `totalAssets` ~**54k** PYUSD. Too small, extra Sky/Spark risk. Not this listing.

## Status

`skip` as L. Optional later **C1** only if we want a HyperEVM dollar from Paxos — that is Leaf Market inventory, not a yield leaf. **Not** BATCH 5 / JitoSOL. Solana mint waits on the Solana program the same way any SPL does, but that does not make PYUSD an LST.
