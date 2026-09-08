// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Source-chain claim. Must pay `lockbox` and must not move inner.
///         Anyone may poke `harvest(lockbox)` if the farm already credits the box.
interface ILeafRewardSource {
    function harvest(address lockbox) external;
}
