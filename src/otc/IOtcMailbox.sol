// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Transport between a source lockbox and a HyperEVM claim token.
///         `OtcSameChainMailbox` is tests only. Production uses `OtcLzMailbox`.
interface IOtcMailbox {
    function notifyDeposit(address destTo, uint256 amount) external payable;
    function notifyRedeem(address srcTo, uint256 amount) external payable;
}
