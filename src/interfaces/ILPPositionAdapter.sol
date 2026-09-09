// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ILPPositionAdapter
/// @notice Venue-specific execution boundary for HyperLeaf-managed LP positions.
/// @dev The manager owns policy and limits; adapters own venue-specific mechanics.
interface ILPPositionAdapter {
    struct PositionState {
        address token0;
        address token1;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 amount0;
        uint256 amount1;
        uint256 fees0;
        uint256 fees1;
    }

    struct RebalanceParams {
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
        bytes venueData;
    }

    struct RebalanceResult {
        uint256 amount0Spent;
        uint256 amount1Spent;
        uint256 amount0Received;
        uint256 amount1Received;
        uint128 newLiquidity;
    }

    function positionState(bytes32 positionId) external view returns (PositionState memory);

    /// @notice Rebalance one registered position under the manager's execution limits.
    /// @dev Must only be callable by the configured LPPositionManager.
    function rebalance(
        bytes32 positionId,
        RebalanceParams calldata params
    ) external returns (RebalanceResult memory result);

    /// @notice Collect venue-level LP fees without changing the target range.
    /// @dev Optional for adapters; managers may expose this as a separate keeper action later.
    function collectFees(bytes32 positionId, bytes calldata venueData)
        external
        returns (uint256 amount0, uint256 amount1);
}
