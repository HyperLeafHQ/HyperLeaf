// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LeafMerkleClaim} from "./LeafMerkleClaim.sol";

/// @notice hKAITO pins. Wrap sKAITO on Base. Never raw KAITO. Never the
///         official 7d unstake. Eco ERC-20s are yield: owner allowlists the
///         campaign distributor, anyone `pokeMerkleClaim`, then `pullYield`.
///         Extra-chain campaigns need the CREATE2 holder at the same address.
///         Not a MainnetBatch. No GO.
library LeafKaitoPolicy {
    address internal constant SKAITO = 0x548D3B444da39686d1a6F1544781d154e7cD1EF7;
    address internal constant KAITO = 0x98d0baa52b2D063E780DE12F615f963Fe8537553;
    bytes4 internal constant MERKLE_CLAIM = LeafMerkleClaim.SELECTOR;

    error NotSkaito();

    function requireSkaito(address inner) internal pure {
        if (inner != SKAITO) revert NotSkaito();
    }
}
