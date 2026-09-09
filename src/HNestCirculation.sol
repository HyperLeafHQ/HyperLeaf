// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title HNestCirculation
/// @notice hNEST circulation / reward-accounting gate. Independent of HEV's
///         4-day dettach lock and of NestVault.DETACHMENT_LOCK_DURATION.
///
///         4 days  = HEV / live NestVault dettach (custody). We do not own HEV.
///         7 days  = Nest economic epoch (Thursday 00:00 UTC; unix epoch is Thursday).
///         8 days  = HyperLeaf minimum circulation delay.
///
///         claimableAt = max(depositTs + 8 days, epochEnd(depositTs) + 30 minutes)
///
///         Live NestVault 0x4f6615… mints transferable hNEST immediately and is
///         immutable. This library is the spec for frontend / any future wrap.
///         Do not fold this delay into dettachForLiquidity.
library HNestCirculation {
    uint256 internal constant HNEST_MIN_DELAY = 8 days;
    uint256 internal constant NEST_EPOCH = 7 days;
    /// @dev Keeper harvests Thursday 00:30 UTC (epoch end + 30m).
    uint256 internal constant SETTLEMENT_BUFFER = 30 minutes;

    /// @dev Unix 0 is Thursday 00:00 UTC, so `ts / 7 days * 7 days` is the
    ///      Thursday that opened the epoch containing `ts`.
    function epochEnd(uint256 depositTs) internal pure returns (uint256) {
        return (depositTs / NEST_EPOCH) * NEST_EPOCH + NEST_EPOCH;
    }

    function claimableAt(uint256 depositTs) internal pure returns (uint256) {
        uint256 minDelay = depositTs + HNEST_MIN_DELAY;
        uint256 settled = epochEnd(depositTs) + SETTLEMENT_BUFFER;
        return minDelay >= settled ? minDelay : settled;
    }
}
