// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Source-chain claim adapter. Must send rewards to `lockbox` and
///         must not move inner principal. Anyone may poke `harvest(lockbox)`
///         Anyone may poke `harvest(lockbox)` (farm or LeafCallRewardSource).
interface ILeafRewardSource {
    function harvest(address lockbox) external;
}
