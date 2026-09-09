# Stable Asset Protection Layer

HyperLeaf can list many kinds of stable-asset-backed Leaf products: issuer-backed stablecoins such as PYUSD / USDG, lending positions such as Aave USDC, ERC-4626 positions such as Morpho DAI, and venue-specific USDT / USD1 strategies.

These assets share a UX requirement (they should behave like a claim close to fiat value) but they do **not** share the same peg or redemption mechanism. The protocol therefore needs a generic protection layer instead of a new market.

## Architecture

```text
                         HyperLeaf
                             |
                +------------+-------------+
                |                          |
        StableAssetController         Leaf Market
                |                     (secondary exit)
        +-------+--------+
        |       |        |
      Peg     Exit     Buffer
      state   state    (optional)
        |       |        |
        +-------+--------+
                |
        IStableAssetAdapter
                |
      venue-specific proof / redemption
```

**Leaf Market answers:** “What price will another user pay for this transferable Leaf?”

**StableAssetController answers:** “Are normal issuance and ordinary market-discount semantics currently safe for this stable-asset listing?”

The controller is not an oracle, not a treasury market maker, and not a promise that an external stablecoin remains at $1.

## Normalized risk model

Each listing exposes two independent evidence streams:

- `PegState`: market/reference price, primary redemption price, update timestamp, and deviation.
- `ExitState`: total normalized claim, immediately redeemable capacity, approved protocol buffer, queue amount, and update timestamp.

The controller derives:

- `PegStatus`: `Normal`, `Warning`, `Degraded`, `Broken`.
- `ExitMode`: `MarketOnly`, `PrimaryRedeem`, `BufferedRedeem`, `QueueRedeem`, `Frozen`.
- `exitCoverageBps = (immediatelyRedeemable + bufferedLiquidity) / totalClaim`.

Stale evidence is treated as a risk state, not as a healthy price.

## Leaf Market compatibility

The existing Leaf Market remains the secondary liquidity venue. Its existing rule is intentionally preserved: it is an on-chain escrow / matching surface and does not make the protocol the counterparty. fileciteturn85file0L2-L2

For stable listings, the integration should call `canUseLeafMarket(listingId)` before presenting an ask as an **ordinary liquidity discount**.

- Healthy peg + fresh evidence + adequate exit coverage → ordinary market discount is allowed.
- Warning / degraded or weak exit evidence → surface a risk warning; do not represent the ask as a clean fiat exit.
- Broken or stale evidence → market disabled by policy.

This keeps a 30 bps secondary-market discount distinct from a 10% impairment in the underlying stable asset.

## Why no second stable Leaf token

The framework deliberately does not mint `hPYUSD2`, `hUSDC2`, etc. The existing Leaf remains the transferable receipt. Stable-specific behavior lives in adapter/controller state so the accounting surface stays compatible with existing Leaf Market infrastructure.

## Primary exit and buffer

`IStableAssetAdapter` provides optional venue-specific primary redemption hooks. The controller only validates policy; it does not custody or impersonate the underlying issuer / protocol.

`IStableExitBuffer` is an optional bounded liquidity backstop. A production implementation should constrain it by:

1. approved cash-equivalent assets;
2. per-listing maximum inventory;
3. per-transaction and daily outflow limits;
4. independent emergency pause / governance controls.

The buffer is an exit backstop, not an AMM and not a permanent treasury bid.

## Accounting rule

Stablecoin impairment is a **solvency / liquidity event**, not generic yield. A path such as `1.00 → 0.90 → 1.00` must not create artificial yield merely because the observed price temporarily moved.

Face value still comes from the listing's normalized solvency unit, not from an arbitrary USD oracle. The controller consumes reference price only as a health-policy signal.

## Risk configuration

```solidity
struct RiskConfig {
    uint16 maxPegDeviationBps;
    uint16 maxExitDiscountBps;
    uint16 minExitCoverageBps;
    uint32 maxEvidenceAge;
    uint16 maxPrimaryRedeemSlippageBps;
    bool requirePrimaryRedeem;
}
```

Recommended deployment policy is to start with conservative thresholds and widen them only through explicit governance / review.

## Asset classes

| Class | Example | Main risk | Adapter responsibility |
| --- | --- | --- | --- |
| Issuer-backed | PYUSD, USDG | issuer / reserve / redemption | reserve + redemption evidence |
| DeFi-backed stable position | Aave USDC, Morpho DAI | utilization, market liquidity, smart-contract / credit risk | withdrawable liquidity + share/NAV evidence |
| Venue-specific stable strategy | Bitway USDT, HertzFlow USD1 | venue credit / withdrawal / bridge risk | canonical claim + exit path evidence |

The controller does not assume these classes are economically equivalent; it only gives them the same normalized interface.

## Implementation status

This PR is a framework layer only. It adds interfaces, policy evaluation, and tests. Concrete adapters for PYUSD, USDG, Aave USDC, Bitway USDT, HertzFlow USD1, and Morpho DAI should be separate integrations after their redemption, reserve, liquidity, and failure-mode evidence is verified.

## Security invariants

1. No normal minting when peg evidence is stale or broken.
2. No ordinary Leaf Market discount semantics when evidence is stale/broken or exit capacity is below policy.
3. Primary-exit policy is checked against fresh evidence and maximum slippage.
4. Stable impairment is never booked as generic yield by this controller.
5. The controller never assumes `balanceOf()` is the face value of a complex underlying position.
6. An optional buffer is bounded and independent from Leaf Market pricing.
7. A venue adapter remains responsible for its own redemption proof / execution.
