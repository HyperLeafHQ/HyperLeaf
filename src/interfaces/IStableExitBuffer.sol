// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Optional protocol-owned exit liquidity surface. A buffer is not a market:
///         it exists only to cover a bounded portion of stable-asset exits.
interface IStableExitBuffer {
    function available(bytes32 listingId) external view returns (uint256 assets);
    function maxDailyOutflow(bytes32 listingId) external view returns (uint256 assets);
    function preview(bytes32 listingId, uint256 assets) external view returns (uint256 received);
    function provide(bytes32 listingId, uint256 assets, address receiver) external returns (uint256 received);
}
