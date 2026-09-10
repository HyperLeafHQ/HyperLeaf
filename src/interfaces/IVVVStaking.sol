// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Verification-stage interface for Venice VVV staking.
/// @dev ABI MUST be confirmed against the deployed Base staking contract before use.
interface IVVVStaking {
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function claimRewards() external;
    function stakedBalance(address account) external view returns (uint256);
    function pendingRewards(address account) external view returns (uint256);
    function emissionRatePerSecond() external view returns (uint256);
}
