// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVirtualRewarder
 * @notice Nest SingelTokenVirtualRewarder (HEV) — confirmed HyperEVM selectors.
 * @dev getReward(address) / earned(address) do NOT exist. harvest is strategy-gated.
 *      User pending = calculateAvailableRewardsAmount(tokenId) (NEST share).
 */
interface IVirtualRewarder {
    function balanceOf(uint256 tokenId) external view returns (uint256);
    function calculateAvailableRewardsAmount(uint256 tokenId) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function strategy() external view returns (address);
    /// @dev Strategy-only; non-strategy callers get AccessDenied.
    function harvest(uint256 tokenId) external returns (uint256 reward);
}
