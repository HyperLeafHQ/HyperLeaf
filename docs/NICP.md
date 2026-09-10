# hnICP — no EVM LST. ICP canisters only

Verified 2026-09-10. Official WaterNeuron, not eval.

## Gate 0

No Ethereum nICP. LayerZero has **no ICP eid** in the public deployment list (2026-09). Internet Computer is ICRC canisters, not EVM.

Canonical LST: WaterNeuron **nICP**.

| | Official |
| --- | --- |
| Protocol | `tsbvt-pyaaa-aaaar-qafva-cai` |
| nICP ledger | `buwm7-7yaaa-aaaar-qagva-cai` |
| Index | `btxkl-saaaa-aaaar-qagvq-cai` |
| ICP ledger | `ryjl3-tyaaa-aaaaa-aaaba-cai` |
| Docs | https://docs.waterneuron.fi/more/canisters |
| Live | ~2.37M ICP in 6-month neurons, ~8% APY, 10% protocol fee on rewards. Rate ~0.787 nICP per ICP (value-accruing). |

nICP is a token for ICP locked in a **6-month neuron**. Unstake nICP → wait the dissolve. Lockbox must **never** dissolve the neuron.

Do not wrap:
- raw ICP
- an NNS neuron we operate (dissolve 6 months–2 years, voting)
- random “wrapped ICP” ERC-20s on Ethereum (spot)

## Status

`later-non-evm`. Same bucket as Stride stATOM: wrap the LST on its native chain after a non-EVM lockbox exists. **After hJitoSOL**, and ICP is a **third** runtime (canisters), not Solana and not IBC. Do not start an ICP adapter now.
