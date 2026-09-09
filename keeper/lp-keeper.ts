import * as cron from "node-cron";
import { defineChain, type Hex } from "viem";
import { LPKeeper, address } from "./lp/runner.js";
import { RecenterRangeStrategy } from "./lp/strategy.js";
import type { LPPositionConfig } from "./lp/types.js";

const hyperEVM = defineChain({
  id: 999,
  name: "HyperEVM",
  nativeCurrency: { name: "HYPE", symbol: "HYPE", decimals: 18 },
  rpcUrls: { default: { http: ["https://rpc.hyperliquid.xyz/evm"] } },
});

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`missing environment variable: ${name}`);
  return value;
}

function integer(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw) return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value)) throw new Error(`${name} must be an integer`);
  return value;
}

function bigintEnv(name: string, fallback = "0"): bigint {
  const raw = process.env[name] ?? fallback;
  try {
    return BigInt(raw);
  } catch {
    throw new Error(`${name} must be an integer amount`);
  }
}

const positionId = required("LP_POSITION_ID") as Hex;
if (!/^0x[0-9a-fA-F]{64}$/.test(positionId)) {
  throw new Error("LP_POSITION_ID must be a 32-byte hex value");
}

const config: LPPositionConfig = {
  id: positionId,
  manager: address(required("LP_MANAGER_ADDRESS")),
  adapter: address(required("LP_ADAPTER_ADDRESS")),
  maxAmount0In: bigintEnv("LP_MAX_AMOUNT0_IN"),
  maxAmount1In: bigintEnv("LP_MAX_AMOUNT1_IN"),
  slippageBps: integer("LP_SLIPPAGE_BPS", 100),
  minRebalanceIntervalSeconds: integer("LP_MIN_REBALANCE_INTERVAL", 900),
  rangeWidthTicks: integer("LP_RANGE_WIDTH_TICKS", 1200),
  triggerDistanceTicks: integer("LP_TRIGGER_DISTANCE_TICKS", 120),
  venueData: (process.env.LP_VENUE_DATA ?? "0x") as Hex,
};

const keeper = new LPKeeper({
  chain: hyperEVM,
  rpcUrl: process.env.HYPEREVM_RPC_URL ?? "https://rpc.hyperliquid.xyz/evm",
  privateKey: required("KEEPER_PRIVATE_KEY") as `0x${string}`,
  dryRun: process.env.LP_KEEPER_DRY_RUN !== "false",
});

const strategy = new RecenterRangeStrategy();

async function tick(): Promise<void> {
  try {
    const hash = await keeper.runOnce(config, strategy);
    if (hash) console.log(`[lp] submitted ${hash}`);
  } catch (error) {
    console.error(`[lp] keeper iteration failed`, error);
  }
}

console.log(`[lp] generic manager started for ${positionId}`);
console.log(`[lp] dry-run=${process.env.LP_KEEPER_DRY_RUN !== "false"}`);

void tick();
cron.schedule("*/1 * * * *", () => void tick(), { timezone: "UTC" });
