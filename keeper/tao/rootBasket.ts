import type {Hex} from "viem";

/**
 * Remote Bittensor identity. Keep SS58 decoding out of the EVM-facing layer;
 * the normalized AccountId32 is carried as 32 raw bytes.
 */
export type TaoRootIdentity = {
  coldkey: Hex;
  validatorHotkey: Hex;
};

export type TaoRootSnapshot = TaoRootIdentity & {
  netuid: number;
  rootStakeRao: bigint;
  betaRaw: bigint;
  valueTaoRao: bigint;
  remoteBlock: bigint;
  specVersion: number;
  stateHash: Hex;
};

export interface BittensorRootClient {
  /**
   * Query a validator fund / basket using Bittensor's canonical runtime API.
   * The implementation should use the current chain SDK/RPC and must not
   * synthesize value from wallet balances or an external price oracle.
   */
  getValidatorBasket(
    validatorHotkey: Hex,
  ): Promise<ReadonlyArray<{netuid: number; alphaRaw: bigint; taoValueRao: bigint}>>;

  /** Current realizable TAO entitlement for one coldkey + validator. */
  getBetaPosition(
    validatorHotkey: Hex,
    coldkey: Hex,
  ): Promise<{
    betaRaw: bigint;
    valueTaoRao: bigint;
  } | null>;

  /** Total basket entitlement across the coldkey. */
  getRootBasketOwed(coldkey: Hex): Promise<bigint>;

  getHead(): Promise<{remoteBlock: bigint; specVersion: number}>;
}

export type RootPositionKey = `${Hex}:${Hex}`;

export function positionId(coldkey: Hex, validatorHotkey: Hex): RootPositionKey {
  return `${coldkey}:${validatorHotkey}`;
}

export async function readRootPosition(
  client: BittensorRootClient,
  coldkey: Hex,
  validatorHotkey: Hex,
): Promise<TaoRootSnapshot> {
  const [position, head] = await Promise.all([
    client.getBetaPosition(validatorHotkey, coldkey),
    client.getHead(),
  ]);

  if (!position) {
    throw new Error("Bittensor Root Basket position not found");
  }

  return {
    coldkey,
    validatorHotkey,
    netuid: 0,
    rootStakeRao: 0n,
    betaRaw: position.betaRaw,
    valueTaoRao: position.valueTaoRao,
    remoteBlock: head.remoteBlock,
    specVersion: head.specVersion,
    // Production implementation must hash the exact canonical proof payload.
    stateHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
  };
}
