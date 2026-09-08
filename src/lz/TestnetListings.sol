// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AssetCatalog} from "./AssetCatalog.sol";
import {TestnetCatalog} from "./TestnetCatalog.sol";
import {NextTestnetCatalog} from "./NextTestnetCatalog.sol";
import {FourthTestnetCatalog} from "./FourthTestnetCatalog.sol";

/// @notice Script helper. Round 1 → Next (hgSOON/…) → Fourth (hORDER).
///         hsWBERA is mainnet-only and reverts here.
library TestnetListings {
    function get(string memory id) internal pure returns (AssetCatalog.Listing memory) {
        bytes32 k = keccak256(bytes(id));
        if (k == keccak256("hswbera")) revert NextTestnetCatalog.NotThisRound();
        if (k == keccak256("horder") || k == keccak256("hORDER")) {
            return FourthTestnetCatalog.get(id);
        }
        if (
            k == keccak256("hgsoon") || k == keccak256("hsavax") || k == keccak256("hstkwausdc")
                || k == keccak256("hstkwaUSDC") || k == keccak256("hsethfi") || k == keccak256("hethfi")
                || k == keccak256("hsETHFI")
        ) return NextTestnetCatalog.get(id);
        return TestnetCatalog.get(id);
    }
}
