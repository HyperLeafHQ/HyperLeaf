# 4626 listings — rate jump + proxy identity

Reply to the hsGHO / hsUSDf / hsFF review.

| Finding | Verdict |
| --- | --- |
| ConvertToAssets `maxRateJumpBps` default 0 | **fixed.** Configure sets **300** (same as LBTC / sPOL) before capital. Frozen once `totalLocked>0`. |
| hsUSDf proxy, policy only checks address | **fixed at configure:** `require*Live` also requires `asset()` == GHO / USDf / FF. **Will not pin EIP-1967 impl** — a legitimate Falcon/Aave upgrade keeps the proxy. Pinning impl would force a false re-deploy. Runtime still reads `convertToAssets` on that proxy; a malicious upgrade that keeps `asset()` but lies on rate is what the 300 bps breaker is for. |
| `allIds()` missed new listings | **fixed.** `allIds` is 22 and includes `havnt` / `hlbtc` / `hhbarx` / `hsgho` / `hsusdf` / `hsff`. |
| hstNEAR / hXM not in Solidity catalog | **won't add.** 24-dec OFT path and MemeCore missing Horizen+Canary. JSON + NotThisBatch is the record. Do not re-open as a solidity coverage gap until those blockers move. |
