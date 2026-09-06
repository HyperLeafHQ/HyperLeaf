/**
 * hNEST Keeper脚本（草稿 — 需按主网 runbook 重写）
 * 每周四 00:30 UTC（epoch结束后30分钟）自动执行
 *
 * 功能：
 * 1. 调用 harvest()：扫 adapter 残余 HYPE ERC20（通常为 0）、处理赎回队列
 *    — 不投票；不 invent Nest 液态 HYPE；recordCompound 已禁用
 * 2. 监控赎回队列 / idle 缺口（应扩展 dettachForLiquidity + topUpIdle）
 * 3. 异常告警
 *
 * 角色：Keeper = Hyperleaf 热钱包；绝非 Owner/Guardian。
 *
 * 运行：npx ts-node keeper.ts
 * 推荐部署在：Railway / Render / 任意VPS
 */

import { createPublicClient, createWalletClient, http, parseAbi } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { defineChain } from "viem";
import * as cron from "node-cron";

// ============ HyperEVM链配置 ============
const hyperEVM = defineChain({
  id: 999, // 请确认实际chain id
  name: "HyperEVM",
  nativeCurrency: { name: "HYPE", symbol: "HYPE", decimals: 18 },
  rpcUrls: {
    default: { http: ["https://rpc.hyperliquid.xyz/evm"] },
  },
});

// ============ 配置（从环境变量读取） ============
const KEEPER_PRIVATE_KEY = process.env.KEEPER_PRIVATE_KEY as `0x${string}`;
const VAULT_ADDRESS = process.env.VAULT_ADDRESS as `0x${string}`;
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN; // 可选，用于告警
const TELEGRAM_CHAT_ID = process.env.TELEGRAM_CHAT_ID;

// ============ 投票策略 ============
// HEV auto-votes — keeper 不再投票。以下为历史占位，勿启用。
// const VOTE_POOLS_UNUSED = [];

// ============ ABI ============
const VAULT_ABI = parseAbi([
  "function harvest() external",
  "function sharePrice() external view returns (uint256)",
  "function totalVeNFTs() external view returns (uint256)",
  "function withdrawQueueStatus() external view returns (uint256 totalRequests, uint256 processedRequests, uint256 pendingRequests)",
  "function totalNestLocked() external view returns (uint256)",
]);

// ============ 客户端初始化 ============
const account = privateKeyToAccount(KEEPER_PRIVATE_KEY);

const publicClient = createPublicClient({
  chain: hyperEVM,
  transport: http(),
});

const walletClient = createWalletClient({
  account,
  chain: hyperEVM,
  transport: http(),
});

// ============ 主要功能 ============

async function runHarvest() {
  console.log(`[${new Date().toISOString()}] 开始执行harvest...`);

  try {
    // 执行harvest
    const hash = await walletClient.writeContract({
      address: VAULT_ADDRESS,
      abi: VAULT_ABI,
      functionName: "harvest",
      gas: BigInt(5000000), // 预估gas，实际根据NFT数量调整
    });

    console.log(`harvest交易已发送: ${hash}`);

    // 等待交易确认
    const receipt = await publicClient.waitForTransactionReceipt({ hash });
    console.log(`harvest成功，区块: ${receipt.blockNumber}`);

    // 查询执行后状态
    await reportStatus();

  } catch (error) {
    const msg = `❌ harvest失败: ${error}`;
    console.error(msg);
    await sendAlert(msg);
  }
}

async function reportStatus() {
  try {
    const [sharePrice, totalVeNFTs, queueStatus, totalNestLocked] = await Promise.all([
      publicClient.readContract({
        address: VAULT_ADDRESS,
        abi: VAULT_ABI,
        functionName: "sharePrice",
      }),
      publicClient.readContract({
        address: VAULT_ADDRESS,
        abi: VAULT_ABI,
        functionName: "totalVeNFTs",
      }),
      publicClient.readContract({
        address: VAULT_ADDRESS,
        abi: VAULT_ABI,
        functionName: "withdrawQueueStatus",
      }),
      publicClient.readContract({
        address: VAULT_ADDRESS,
        abi: VAULT_ABI,
        functionName: "totalNestLocked",
      }),
    ]);

    const [totalRequests, processedRequests, pendingRequests] = queueStatus as bigint[];

    const report = `
📊 hNEST协议状态报告
━━━━━━━━━━━━━━━━
净值: ${Number(sharePrice as bigint) / 1e18} NEST/hNEST
总锁定NEST: ${Number(totalNestLocked as bigint) / 1e18}
持有veNFT数量: ${totalVeNFTs}
赎回队列: ${pendingRequests}笔待处理
━━━━━━━━━━━━━━━━
时间: ${new Date().toISOString()}
    `.trim();

    console.log(report);
    await sendAlert(report);

  } catch (error) {
    console.error("状态查询失败:", error);
  }
}

async function sendAlert(message: string) {
  if (!TELEGRAM_BOT_TOKEN || !TELEGRAM_CHAT_ID) return;

  try {
    const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;
    await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: TELEGRAM_CHAT_ID,
        text: message,
        parse_mode: "Markdown",
      }),
    });
  } catch (error) {
    console.error("Telegram告警发送失败:", error);
  }
}

// ============ 定时任务 ============

// 每周四 00:30 UTC执行（epoch结束后30分钟）
// cron格式：分 时 日 月 星期（0=周日，4=周四）
cron.schedule("30 0 * * 4", async () => {
  console.log("开始执行每周自动化任务...");
  await runHarvest();
}, {
  timezone: "UTC"
});

// 每天查询一次状态
cron.schedule("0 12 * * *", async () => {
  await reportStatus();
}, {
  timezone: "UTC"
});

console.log("hNEST Keeper已启动，等待执行时间...");
console.log("每周四 00:30 UTC 执行harvest");

// 立即执行一次状态查询
reportStatus();
