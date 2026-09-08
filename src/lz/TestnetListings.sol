// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AssetCatalog} from "./AssetCatalog.sol";
import {TestnetCatalog} from "./TestnetCatalog.sol";
import {NextTestnetCatalog} from "./NextTestnetCatalog.sol";

/// @notice Script helper: round-1 lock + hgSOON. Unknown ids still revert.
library TestnetListings {
    function get(string memory id) internal pure returns (AssetCatalog.Listing memory) {
        bytes32 k = keccak256(bytes(id));
        if (
            k == keccak256("hgsoon") || k == keccak256("hsavax") || k == keccak256("hstkwausdc")
                || k == keccak256("hstkwaUSDC")
        ) return NextTestnetCatalog.get(id);
        return TestnetCatalog.get(id);
    }
}
