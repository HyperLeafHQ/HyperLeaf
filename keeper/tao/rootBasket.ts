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
  netuid: 0;
  rootStakeRao: bigint;
  betaRaw: bigint;
  valueTaoRao: bigint;
  remoteBlock: bigint;
  specVersion: number;
  stateHash: Hex;
};

export interface BittensorRootClient {
  /** Current root principal for this coldkey delegated to this validator. */
  getRootStakeRao(validatorHotkey: Hex, coldkey: Hex): Promise<bigint>;

  /**
   * Query one validator's basket using Bittensor's canonical runtime API.
   * `taoValueRao` is the current realizable quote, not a spot-oracle NAV.
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

/**
 * Normalize the remote state. The production proof layer must supply a hash
 * over the exact canonical proof payload accepted by the verifier. The
 * resulting snapshot must never be sent to the EVM adapter as self-attested data.
 */
export async function readRootPosition(
  client: BittensorRootClient,
  coldkey: Hex,
  validatorHotkey: Hex,
  stateHash: Hex,
): Promise<TaoRootSnapshot> {
  const [rootStakeRao, position, head] = await Promise.all([
    client.getRootStakeRao(validatorHotkey, coldkey),
    client.getBetaPosition(validatorHotkey, coldkey),
    client.getHead(),
  ]);

  if (!position) {
    throw new Error("Bittensor Root Basket position not found");
  }
  if (/^0x0{64}$/i.test(stateHash)) {
    throw new Error("stateHash must come from the authenticated proof layer");
  }

  return {
    coldkey,
    validatorHotkey,
    netuid: 0,
    rootStakeRao,
    betaRaw: position.betaRaw,
    valueTaoRao: position.valueTaoRao,
    remoteBlock: head.remoteBlock,
    specVersion: head.specVersion,
    stateHash,
  };
}
