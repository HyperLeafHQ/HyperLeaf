// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AssetCatalog} from "./AssetCatalog.sol";

/// @notice Batch 4 testnet: hORDER only (Arb Sepolia → HyperEVM 998).
///         Single-chain C1. Do not add to TestnetCatalog / NextTestnetCatalog.
library FourthTestnetCatalog {
    error NotThisRound();

    function get(string memory id) internal pure returns (AssetCatalog.Listing memory) {
        bytes32 k = keccak256(bytes(id));
        if (k != keccak256("horder") && k != keccak256("hORDER")) revert NotThisRound();
        return AssetCatalog.get("horder");
    }
}
