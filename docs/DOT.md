# hvDOT — delay. Old coin, still not an easy EVM wrap

Verified 2026-09-10. Age is not the issue. Native stake is Polkadot nomination, **28-day** unbond. That is not a Leaf listing.

## Do not wrap

| | |
| --- | --- |
| Raw DOT | No yield in the token |
| Nomination pool / OpenGov lock | Not an ERC-20 |
| StellaSwap **stDOT** | Sunset 2026-03-02 |
| ETH vDOT `0xBC33…7Fe5` | ~24.8k. Bridged copy |
| BSC vDOT same addr | ~29.7k. Hyperbridge copy. Tiny |
| HyperEVM | No vDOT at the Moonbeam xc address |

## Canonical LST

**Bifrost vDOT** — yield in exchange rate, redeem ≤28d. Official mint is Bifrost parachain SLP. EVM face: Moonbeam xc20 `0xFFFfffFf15e1b7E3dF971DD813Bc394deB899aBf` (Bifrost SLPX docs). LZ Moonbeam eid **30126** exists but we have **zero** Moonbeam listings. Acala LDOT is another parachain pallet, same XCM class.

Wrapping xc vDOT is a **new source chain + XCM redeem**, not `LeafOFTAdapter` on BSC.

## Status

`later`. After hJitoSOL / a first Moonbeam path. Never native DOT. Coin being old does not move it up.
