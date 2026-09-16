// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hslisBNB pins. Lista slisBNB on BSC only. Rate is StakeManager
///         `convertSnBnbToBnb`, not ERC-4626 on the token. Never native BNB.
library LeafListaPolicy {
    address internal constant SLISBNB = 0xB0b84D294e0C75A6abe60171b70edEb2EFd14A1B;
    address internal constant STAKE_MANAGER = 0x1adB950d8bB3dA4bE104211D5AB038628e477fE6;

    error NotSlisBnb();

    function requireSlisBnb(address inner) internal pure {
        if (inner != SLISBNB) revert NotSlisBnb();
    }
}
