// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AssetCatalog} from "./AssetCatalog.sol";

/// @notice After the locked four-asset round. First unlock: hgSOON (BSC testnet 97).
///         hstkwaUSDC / hsAVAX stay out until their mocks exist. Do not add them here.
library NextTestnetCatalog {
    error NotThisRound();

    function get(string memory id) internal pure returns (AssetCatalog.Listing memory) {
        if (keccak256(bytes(id)) != keccak256("hgsoon")) revert NotThisRound();
        return AssetCatalog.get(id);
    }
}
