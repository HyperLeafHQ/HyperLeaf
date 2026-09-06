// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IHevStrategy
 * @notice Nest CompoundVeNESTManagedNFTStrategyUpgradeable views / operator claims.
 * @dev claimRewards / claimBribes act on the managed NFT gauges (operator path),
 *      not a per-user HYPE Spring claim. User pending = getLockedRewardsBalance (NEST).
 */
interface IHevStrategy {
    function managedTokenId() external view returns (uint256);
    function virtualRewarder() external view returns (address);
    function getLockedRewardsBalance(uint256 tokenId_) external view returns (uint256);
    function balanceOf(uint256 tokenId_) external view returns (uint256);
    function claimRewards(address[] calldata gauges_) external;
    function claimBribes(address[] calldata bribes_, address[][] calldata tokens_) external;
}
