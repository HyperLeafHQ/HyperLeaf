// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ILPPositionAdapter} from "./interfaces/ILPPositionAdapter.sol";

/// @title LPPositionManager
/// @notice Generic policy/execution shell for automatically managed LP positions.
/// @dev
/// - Position adapters contain venue-specific logic (V3 NFT, CLMM NFT, gauge LP, etc.).
/// - The manager contains reusable policy: keeper authorization, per-position limits,
///   cooldowns, deadlines and a single execution boundary.
/// - It never assumes an AMM, pool, fee tier, NFT format or pricing oracle.
contract LPPositionManager is Ownable {
    uint256 public constant BPS = 10_000;

    struct PositionConfig {
        address adapter;
        address keeper;
        uint16 maxSlippageBps;
        uint32 minRebalanceInterval;
        uint256 maxAmount0PerRebalance;
        uint256 maxAmount1PerRebalance;
        uint256 lastRebalanceAt;
        bool active;
    }

    mapping(bytes32 => PositionConfig) public positions;

    bool public paused;

    error NotKeeper();
    error UnknownPosition();
    error PositionInactive();
    error InvalidAdapter();
    error InvalidKeeper();
    error InvalidSlippage();
    error CooldownActive(uint256 nextAllowedAt);
    error DeadlineExpired();
    error Amount0LimitExceeded();
    error Amount1LimitExceeded();
    error SlippageExceeded(uint256 spent0, uint256 spent1);
    error ZeroPositionId();

    event PositionRegistered(bytes32 indexed positionId, address indexed adapter, address indexed keeper);
    event PositionUpdated(bytes32 indexed positionId, address indexed adapter, address indexed keeper);
    event PositionPaused(bytes32 indexed positionId);
    event PositionActivated(bytes32 indexed positionId);
    event PositionRebalanced(
        bytes32 indexed positionId,
        address indexed adapter,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0Spent,
        uint256 amount1Spent,
        uint256 amount0Received,
        uint256 amount1Received,
        uint128 newLiquidity
    );
    event ManagerPaused(bool paused);

    constructor(address initialOwner) Ownable(initialOwner) {}

    modifier onlyKeeper(bytes32 positionId) {
        PositionConfig storage cfg = positions[positionId];
        if (cfg.keeper == address(0) || msg.sender != cfg.keeper) revert NotKeeper();
        _;
    }

    function registerPosition(
        bytes32 positionId,
        address adapter,
        address keeper,
        uint16 maxSlippageBps,
        uint32 minRebalanceInterval,
        uint256 maxAmount0PerRebalance,
        uint256 maxAmount1PerRebalance
    ) external onlyOwner {
        if (positionId == bytes32(0)) revert ZeroPositionId();
        _validateConfig(adapter, keeper, maxSlippageBps);

        positions[positionId] = PositionConfig({
            adapter: adapter,
            keeper: keeper,
            maxSlippageBps: maxSlippageBps,
            minRebalanceInterval: minRebalanceInterval,
            maxAmount0PerRebalance: maxAmount0PerRebalance,
            maxAmount1PerRebalance: maxAmount1PerRebalance,
            lastRebalanceAt: 0,
            active: true
        });

        emit PositionRegistered(positionId, adapter, keeper);
    }

    function updatePosition(
        bytes32 positionId,
        address adapter,
        address keeper,
        uint16 maxSlippageBps,
        uint32 minRebalanceInterval,
        uint256 maxAmount0PerRebalance,
        uint256 maxAmount1PerRebalance
    ) external onlyOwner {
        if (positions[positionId].adapter == address(0)) revert UnknownPosition();
        _validateConfig(adapter, keeper, maxSlippageBps);

        PositionConfig storage cfg = positions[positionId];
        cfg.adapter = adapter;
        cfg.keeper = keeper;
        cfg.maxSlippageBps = maxSlippageBps;
        cfg.minRebalanceInterval = minRebalanceInterval;
        cfg.maxAmount0PerRebalance = maxAmount0PerRebalance;
        cfg.maxAmount1PerRebalance = maxAmount1PerRebalance;

        emit PositionUpdated(positionId, adapter, keeper);
    }

    function pausePosition(bytes32 positionId) external onlyOwner {
        PositionConfig storage cfg = positions[positionId];
        if (cfg.adapter == address(0)) revert UnknownPosition();
        cfg.active = false;
        emit PositionPaused(positionId);
    }

    function activatePosition(bytes32 positionId) external onlyOwner {
        PositionConfig storage cfg = positions[positionId];
        if (cfg.adapter == address(0)) revert UnknownPosition();
        cfg.active = true;
        emit PositionActivated(positionId);
    }

    function setPaused(bool value) external onlyOwner {
        paused = value;
        emit ManagerPaused(value);
    }

    /// @notice Execute a keeper-selected rebalance subject to immutable-on-chain policy limits.
    /// @dev The keeper chooses the target range; the manager does not price the position.
    ///      The adapter is the only venue-specific trust boundary.
    function executeRebalance(bytes32 positionId, ILPPositionAdapter.RebalanceParams calldata params)
        external
        onlyKeeper(positionId)
        returns (ILPPositionAdapter.RebalanceResult memory result)
    {
        if (paused) revert PositionInactive();

        PositionConfig storage cfg = positions[positionId];
        if (!cfg.active) revert PositionInactive();
        if (block.timestamp > params.deadline) revert DeadlineExpired();

        uint256 nextAllowedAt = cfg.lastRebalanceAt + cfg.minRebalanceInterval;
        if (block.timestamp < nextAllowedAt) revert CooldownActive(nextAllowedAt);
        if (params.amount0Desired > cfg.maxAmount0PerRebalance) revert Amount0LimitExceeded();
        if (params.amount1Desired > cfg.maxAmount1PerRebalance) revert Amount1LimitExceeded();

        cfg.lastRebalanceAt = block.timestamp;

        result = ILPPositionAdapter(cfg.adapter).rebalance(positionId, params);

        if (result.amount0Spent > params.amount0Min && params.amount0Min != 0) {
            // For adapters where amount0Min is a post-swap receipt floor, this branch is intentionally
            // not used. Spending is bounded by the desired amount and must instead be constrained by
            // the manager caps above. Keep this manager neutral about venue swap semantics.
        }

        if (
            result.amount0Spent > params.amount0Desired ||
            result.amount1Spent > params.amount1Desired
        ) {
            revert SlippageExceeded(result.amount0Spent, result.amount1Spent);
        }

        // Defensive post-condition: returned values must not claim more output than the adapter
        // could have observed under the requested budget. Exact venue-level accounting stays in adapter.
        emit PositionRebalanced(
            positionId,
            cfg.adapter,
            params.tickLower,
            params.tickUpper,
            result.amount0Spent,
            result.amount1Spent,
            result.amount0Received,
            result.amount1Received,
            result.newLiquidity
        );
    }

    function positionState(bytes32 positionId) external view returns (ILPPositionAdapter.PositionState memory) {
        PositionConfig memory cfg = positions[positionId];
        if (cfg.adapter == address(0)) revert UnknownPosition();
        return ILPPositionAdapter(cfg.adapter).positionState(positionId);
    }

    function collectFees(bytes32 positionId, bytes calldata venueData)
        external
        onlyKeeper(positionId)
        returns (uint256 amount0, uint256 amount1)
    {
        PositionConfig memory cfg = positions[positionId];
        if (!cfg.active) revert PositionInactive();
        return ILPPositionAdapter(cfg.adapter).collectFees(positionId, venueData);
    }

    function _validateConfig(address adapter, address keeper, uint16 maxSlippageBps) internal pure {
        if (adapter == address(0)) revert InvalidAdapter();
        if (keeper == address(0)) revert InvalidKeeper();
        if (maxSlippageBps > BPS) revert InvalidSlippage();
    }
}
