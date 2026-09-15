// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Transport between a source lockbox and a HyperEVM claim token.
///         Same-chain mock for tests; LZ/CCTP adapter later. Core must not import this.
interface IOtcMailbox {
    function notifyDeposit(address destTo, uint256 amount) external;
    function notifyRedeem(address srcTo, uint256 amount) external;
}
