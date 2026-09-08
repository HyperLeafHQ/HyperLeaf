// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AssetCatalog} from "./AssetCatalog.sol";

/// @notice This testnet round: hxSQUID, hAVNT (same L claim path), hcbETH, BLUAI4Y.
///         Full catalog stays for later listings. Do not deploy the rest yet.
library TestnetCatalog {
    error NotThisRound();

    function get(string memory id) internal pure returns (AssetCatalog.Listing memory) {
        bytes32 k = keccak256(bytes(id));
        if (
            k != keccak256("hxsquid") && k != keccak256("havnt") && k != keccak256("hcbeth")
                && k != keccak256("bluai4y")
        ) {
            revert NotThisRound();
        }
        return AssetCatalog.get(id);
    }
}
