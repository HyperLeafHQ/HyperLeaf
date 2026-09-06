// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice BLUAI 4-year stake on BSC: 0x94b9865Ef26166fEBB7775d12d6dF23B51465040
/// @dev User txs: stake(amount, 4) 0x8983f3cc…1874 ; claimAll() 0xdf677b0f…c057
interface IBluaiStake {
    function stake(uint256 amount, uint256 years_) external;
    function claimAll() external;
}
