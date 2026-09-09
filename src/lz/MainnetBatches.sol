// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AssetCatalog} from "./AssetCatalog.sol";

/// @notice Go-live order. Cross-chain acceptance is mainnet, not testnet.
///         0 canary (toy inner) → 1 side-token L → 2 rate L → 3 ETH/Avax L → 4 C1.
library MainnetBatches {
    error NotThisBatch();

    uint8 internal constant CANARY = 0;
    uint8 internal constant SIDE_TOKEN = 1;
    uint8 internal constant RATE_L = 2;
    uint8 internal constant ETH_L = 3;
    uint8 internal constant CLOSED = 4;
    uint8 internal constant SOLANA_L = 5;

    function batchOf(string memory id) internal pure returns (uint8) {
        bytes32 k = keccak256(bytes(id));
        if (k == keccak256("hcanary")) return CANARY;
        if (k == keccak256("hxsquid") || k == keccak256("havnt")) return SIDE_TOKEN;
        if (k == keccak256("hcbeth") || k == keccak256("hgsoon") || k == keccak256("hswbera")) return RATE_L;
        if (
            k == keccak256("hsavax") || k == keccak256("hstkwausdc") || k == keccak256("hstkwaUSDC")
                || k == keccak256("hlbtc") || k == keccak256("hLBTC")
        ) return ETH_L;
        if (k == keccak256("bluai4y") || k == keccak256("horder") || k == keccak256("hORDER")) return CLOSED;
        if (k == keccak256("hjitosol") || k == keccak256("hJitoSOL")) return SOLANA_L;
        revert NotThisBatch();
    }

    function get(string memory id) internal pure returns (AssetCatalog.Listing memory) {
        batchOf(id);
        return AssetCatalog.get(id);
    }

    function requireBatch(string memory id, uint8 batch) internal pure {
        if (batchOf(id) != batch) revert NotThisBatch();
    }
}
