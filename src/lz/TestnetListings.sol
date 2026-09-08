// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AssetCatalog} from "./AssetCatalog.sol";
import {TestnetCatalog} from "./TestnetCatalog.sol";
import {NextTestnetCatalog} from "./NextTestnetCatalog.sol";

/// @notice Script helper: round-1 lock + hgSOON. Unknown ids still revert.
library TestnetListings {
    function get(string memory id) internal pure returns (AssetCatalog.Listing memory) {
        if (keccak256(bytes(id)) == keccak256("hgsoon")) return NextTestnetCatalog.get(id);
        return TestnetCatalog.get(id);
    }
}
