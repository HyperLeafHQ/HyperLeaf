// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Virtuals Protocol Stake on Base: 0x60a203ddcDE45fbfb325bdeEA93824B5726b4dF8
/// @dev stake(amount, 104, true) = Auto Max-lock. Max is 2 years; autoRenew keeps ve 1:1.
interface IVirtualsStake {
    function stake(uint256 amount, uint8 numWeeks, bool autoRenew) external;
}
