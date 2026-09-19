// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LeafMerkleClaim} from "./LeafMerkleClaim.sol";

/// @notice hVIRTUALMAX pins. Wrap VIRTUAL on Base, Auto Max-lock 104w.
///         Never official redeem / toggleAutoRenew. Yield is per-campaign
///         agent merkle (0x2e7ba6ef), not VIRTUAL inflation. Base sample
///         0xee45c4… → distributor 0xaec7971f… amount ~44.03e18, account =
///         msg.sender. Robinhood sample 0xa941a3… distributor 0x109c9fa8….
///         Extra-chain needs CREATE2 holder. Dust launches are not allowlisted.
///         Not a MainnetBatch. No GO.
library LeafVirtualsPolicy {
    address internal constant VIRTUAL = 0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b;
    address internal constant STAKE = 0x60a203ddcDE45fbfb325bdeEA93824B5726b4dF8;
    address internal constant BASE_MERKLE_SAMPLE = 0xAEc7971f5E3F161C991A1484a384A78255CE5c56;
    address internal constant RH_MERKLE_SAMPLE = 0x109C9fA8697DAC09be4A528c503b6aD1bbE63b8d;
    bytes4 internal constant MERKLE_CLAIM = LeafMerkleClaim.SELECTOR;
    uint8 internal constant MAX_WEEKS = 104;

    error NotVirtual();

    function requireVirtual(address inner) internal pure {
        if (inner != VIRTUAL) revert NotVirtual();
    }
}
