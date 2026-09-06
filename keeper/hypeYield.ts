/**
 * Convert lockbox surplus → HyperEVM WHYPE → LeafHypeRewarder.notify.
 *
 * Routes
 *  Base:  swap side tokens / extra inner → Wormhole HYPE → Portal/Relay to WHYPE
 *  Solana: Jupiter → Wormhole HYPE mint 98sMhv…Mh5g → Portal to WHYPE
 *  BSC:   swap BLUAI → USDC, then Relay quote destChain=999 destToken=WHYPE.
 *         Fallback deBridge USDC → HyperEVM, then Project X to WHYPE.
 *  Never buy BSC ticker-HYPE or Base cbHYPE.
 *
 * sKAITO extra shares: skip the swap while the Base pool is thin.
 *
 * env: KEEPER_PRIVATE_KEY, ADAPTER, INNER, REWARDER, LISTING_ID, WHYPE
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
