/**
 * Two-step harvest. Do not swap inside the lockbox.
 *
 * 1) Anyone, any time (source chain): LeafCallRewardSource.harvest(lockbox)
 *    or the farm's claim if it already pays the lockbox. Caller pays gas.
 *    — claims QUID / BLUAI into the box. Caller pays gas.
 * 2) Keeper weekly or when surplus > Relay min:
 *    pullYield(allowlisted token) → swap/bridge → LeafHypeRewarder.notify
 *
 * pullInnerEnabled:
 *   false  hKAITO / hxSQUID  (never sell sKAITO or xSQUID)
 *   true   BLUAI4Y           (extra BLUAI only; reserved = totalLocked)
 *
 * Base: QUID / airdrops → Wormhole HYPE → Portal/Relay → WHYPE
 * BSC:  BLUAI → USDC → Relay destChain=999 destToken=WHYPE
 * Never BSC fake HYPE, never cbHYPE.
 */
const RELAY_QUOTE = "https://api.relay.link/quote/v2";
const WHYPE = "0x5555555555555555555555555555555555555555";

export type Route = "base-wormhole" | "solana-wormhole" | "bsc-relay";

export async function quoteBscUsdcToWhype(opts: {
  user: string;
  amount: string;
  recipient: string;
}) {
  const res = await fetch(RELAY_QUOTE, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      user: opts.user,
      originChainId: 56,
      destinationChainId: 999,
      originCurrency: "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d",
      destinationCurrency: WHYPE,
      recipient: opts.recipient,
      tradeType: "EXACT_INPUT",
      amount: opts.amount,
      refundTo: opts.user,
    }),
  });
  if (!res.ok) throw new Error(`relay ${res.status} ${await res.text()}`);
  return res.json();
}

export async function quoteBscUsdcDeBridgeFallback() {
  return {
    note: "If Relay has no fill: deBridge DLN BSC USDC → HyperEVM USDC, then swap WHYPE on Project X. Do not use Pancake HYPE on BSC.",
  };
}

console.log("hypeYield keeper stub — implement pullYield + route + notify per docs/HYPE_YIELD.md");
