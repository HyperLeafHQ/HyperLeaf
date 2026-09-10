// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice GateChain GT native-staking accounting boundary.
/// @dev Research scaffold only. The selectors MUST be reconciled against the
///      verified live GateChain staking ABI before any deployment or custody wiring.
interface IGTStaking {
    function totalStaked() external view returns (uint256);
    function stakedBalance(address account) external view returns (uint256);
    function pendingRewards(address account) external view returns (uint256);
    function previewWithdraw(address account, uint256 shares) external view returns (uint256);
}
