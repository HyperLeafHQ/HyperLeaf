// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal source-side interface for a GateChain GT staking position.
/// @dev Deliberately excludes guessed protocol-specific methods. Concrete wiring must
///      be generated only after the live GateChain staking ABI is verified.
interface IGTStaking {
    function totalStaked() external view returns (uint256);

    function stakedBalance(address account) external view returns (uint256);

    function pendingRewards(address account) external view returns (uint256);

    function previewWithdraw(address account, uint256 shares) external view returns (uint256);
}
