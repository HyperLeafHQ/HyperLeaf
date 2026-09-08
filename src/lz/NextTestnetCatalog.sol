// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AssetCatalog} from "./AssetCatalog.sol";

/// @notice After the locked four-asset round. hgSOON / hsAVAX / hstkwaUSDC.
///         Do not add these ids to TestnetCatalog.
library NextTestnetCatalog {
    error NotThisRound();

    function get(string memory id) internal pure returns (AssetCatalog.Listing memory) {
        bytes32 k = keccak256(bytes(id));
        if (
            k != keccak256("hgsoon") && k != keccak256("hsavax") && k != keccak256("hstkwausdc")
                && k != keccak256("hstkwaUSDC")
        ) revert NotThisRound();
        return AssetCatalog.get(id);
    }
}
