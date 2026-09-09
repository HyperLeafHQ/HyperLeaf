import type { Address, Hex } from "viem";

export type LPPositionState = {
  token0: Address;
  token1: Address;
  tickLower: number;
  tickUpper: number;
  currentTick: number;
  tickSpacing: number;
  liquidity: bigint;
  amount0: bigint;
  amount1: bigint;
  fees0: bigint;
  fees1: bigint;
};

export type LPPositionConfig = {
  id: Hex;
  manager: Address;
  adapter: Address;
  /** Maximum total token budget accepted by the on-chain manager per rebalance. */
  maxAmount0In: bigint;
  maxAmount1In: bigint;
  /** Keeper-level slippage ceiling; the manager enforces this against its stored policy. */
  slippageBps: number;
  /** Minimum spacing between successful rebalance transactions. */
  minRebalanceIntervalSeconds: number;
  /** Concentrated-liquidity strategy parameters. */
  rangeWidthTicks: number;
  triggerDistanceTicks: number;
  /** Optional adapter-encoded action data. */
  venueData?: Hex;
};

export type RebalancePlan = {
  tickLower: number;
  tickUpper: number;
  slippageBps: number;
  amount0InMax: bigint;
  amount1InMax: bigint;
  amount0OutMin: bigint;
  amount1OutMin: bigint;
  deadline: bigint;
  venueData: Hex;
};
