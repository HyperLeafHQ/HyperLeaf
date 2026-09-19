// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Virtuals / ether.fi / KAITO-class merkle.
///         `claim(uint256 index, address account, uint256 amount, bytes32[] proof)`
///         = 0x2e7ba6ef. Account MUST be the lockbox / CREATE2 holder.
///         Never set this as `rewardsSelector` — that path encodes (this, max).
library LeafMerkleClaim {
    bytes4 internal constant SELECTOR = 0x2e7ba6ef;

    function encode(uint256 index, address account, uint256 amount, bytes32[] calldata proof)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(SELECTOR, index, account, amount, proof);
    }
}
