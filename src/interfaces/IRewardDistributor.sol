// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRewardDistributor
 * @notice Legacy HYPE claim surface. Prefer IHevAdapter for HEV path.
 * @dev TODO: replace with real Nest liquid HYPE / MEGAHYPE claim ABI once known. Do not invent paths.
 */
interface IRewardDistributor {
    function claimRewards(uint256[] calldata tokenIds) external;
    function claimable(uint256 tokenId) external view returns (uint256);
}
