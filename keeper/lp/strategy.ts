import type { LPPositionConfig, LPPositionState, RebalancePlan } from "./types.js";

export interface LPStrategy {
  decide(state: LPPositionState, config: LPPositionConfig, nowSeconds: bigint): RebalancePlan | null;
}

/**
 * Simple deterministic CL strategy:
 * - do nothing while the current tick is comfortably inside the position;
 * - when close to an edge or already out of range, recenter a fixed-width range;
 * - snap the target range to the venue's tick spacing.
 *
 * Pricing, swaps and exact liquidity math stay in the venue adapter.
 */
export class RecenterRangeStrategy implements LPStrategy {
  decide(state: LPPositionState, config: LPPositionConfig, nowSeconds: bigint): RebalancePlan | null {
    const nearLower = state.currentTick - state.tickLower <= config.triggerDistanceTicks;
    const nearUpper = state.tickUpper - state.currentTick <= config.triggerDistanceTicks;

    if (!nearLower && !nearUpper) return null;

    if (state.tickSpacing <= 0) {
      throw new Error(`position ${config.id} returned invalid tick spacing ${state.tickSpacing}`);
    }
    if (config.rangeWidthTicks <= 0) {
      throw new Error(`position ${config.id} has invalid range width ${config.rangeWidthTicks}`);
    }

    const center = snapTick(state.currentTick, state.tickSpacing);
    const halfWidth = Math.floor(config.rangeWidthTicks / 2);
    if (halfWidth <= 0) throw new Error("rangeWidthTicks must be >= 2");

    const tickLower = snapTick(center - halfWidth, state.tickSpacing);
    const tickUpper = snapTick(center + halfWidth, state.tickSpacing);
    if (tickLower >= tickUpper) throw new Error("strategy produced an empty range");

    return {
      tickLower,
      tickUpper,
      slippageBps: config.slippageBps,
      amount0InMax: config.maxAmount0In,
      amount1InMax: config.maxAmount1In,
      amount0OutMin: 0n,
      amount1OutMin: 0n,
      deadline: nowSeconds + 120n,
      venueData: config.venueData ?? "0x",
    };
  }
}

function snapTick(tick: number, spacing: number): number {
  const q = Math.floor(tick / spacing);
  return q * spacing;
}
