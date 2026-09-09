import {
  createPublicClient,
  createWalletClient,
  http,
  parseAbi,
  type Address,
  type Chain,
  type Hex,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import type { LPPositionConfig, LPPositionState, RebalancePlan } from "./types.js";
import type { LPStrategy } from "./strategy.js";

const MANAGER_ABI = parseAbi([
  "function positionState(bytes32 positionId) view returns (address token0, address token1, int24 tickLower, int24 tickUpper, int24 currentTick, int24 tickSpacing, uint128 liquidity, uint256 amount0, uint256 amount1, uint256 fees0, uint256 fees1)",
  "function executeRebalance(bytes32 positionId, (int24 tickLower, int24 tickUpper, uint16 slippageBps, uint256 amount0InMax, uint256 amount1InMax, uint256 amount0OutMin, uint256 amount1OutMin, uint256 deadline, bytes venueData) params) returns ((uint256 amount0Spent, uint256 amount1Spent, uint256 amount0Received, uint256 amount1Received, uint128 newLiquidity) result)",
]);

export type LPKeeperOptions = {
  chain: Chain;
  rpcUrl: string;
  privateKey: `0x${string}`;
  dryRun?: boolean;
};

export class LPKeeper {
  private readonly publicClient;
  private readonly walletClient;
  private readonly account;

  constructor(private readonly options: LPKeeperOptions) {
    this.account = privateKeyToAccount(options.privateKey);
    this.publicClient = createPublicClient({
      chain: options.chain,
      transport: http(options.rpcUrl),
    });
    this.walletClient = createWalletClient({
      account: this.account,
      chain: options.chain,
      transport: http(options.rpcUrl),
    });
  }

  async inspect(config: LPPositionConfig): Promise<LPPositionState> {
    const state = await this.publicClient.readContract({
      address: config.manager,
      abi: MANAGER_ABI,
      functionName: "positionState",
      args: [config.id],
    });

    return {
      token0: state[0],
      token1: state[1],
      tickLower: Number(state[2]),
      tickUpper: Number(state[3]),
      currentTick: Number(state[4]),
      tickSpacing: Number(state[5]),
      liquidity: state[6],
      amount0: state[7],
      amount1: state[8],
      fees0: state[9],
      fees1: state[10],
    };
  }

  async evaluate(
    config: LPPositionConfig,
    strategy: LPStrategy,
    nowSeconds = BigInt(Math.floor(Date.now() / 1000)),
  ): Promise<RebalancePlan | null> {
    const state = await this.inspect(config);
    return strategy.decide(state, config, nowSeconds);
  }

  async execute(config: LPPositionConfig, plan: RebalancePlan): Promise<Hex | null> {
    if (this.options.dryRun) {
      console.log(
        JSON.stringify({
          mode: "dry-run",
          positionId: config.id,
          adapter: config.adapter,
          tickLower: plan.tickLower,
          tickUpper: plan.tickUpper,
          slippageBps: plan.slippageBps,
          amount0InMax: plan.amount0InMax.toString(),
          amount1InMax: plan.amount1InMax.toString(),
          deadline: plan.deadline.toString(),
        }),
      );
      return null;
    }

    const { request } = await this.publicClient.simulateContract({
      account: this.account,
      address: config.manager,
      abi: MANAGER_ABI,
      functionName: "executeRebalance",
      args: [
        config.id,
        {
          tickLower: plan.tickLower,
          tickUpper: plan.tickUpper,
          slippageBps: plan.slippageBps,
          amount0InMax: plan.amount0InMax,
          amount1InMax: plan.amount1InMax,
          amount0OutMin: plan.amount0OutMin,
          amount1OutMin: plan.amount1OutMin,
          deadline: plan.deadline,
          venueData: plan.venueData,
        },
      ],
    });

    return this.walletClient.writeContract(request);
  }

  async runOnce(
    config: LPPositionConfig,
    strategy: LPStrategy,
    nowSeconds = BigInt(Math.floor(Date.now() / 1000)),
  ): Promise<Hex | null> {
    const plan = await this.evaluate(config, strategy, nowSeconds);
    if (!plan) return null;

    console.log(
      `[lp] ${config.id} rebalance ${plan.tickLower}:${plan.tickUpper}` +
        ` (current state will be re-read by the transaction simulation)`,
    );
    return this.execute(config, plan);
  }
}

export function address(value: string): Address {
  if (!/^0x[0-9a-fA-F]{40}$/.test(value)) throw new Error(`invalid address: ${value}`);
  return value as Address;
}
