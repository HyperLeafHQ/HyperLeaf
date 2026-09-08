// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Orderly EVM proxy `0xC8A8Ce0A…` (same address on Arb / Base / OP / Eth).
///         Stake and harvest stay on **one** chain for HyperLeaf (Arbitrum).
interface IOrderlyStake {
    function stakeOrder(uint256 amount) external payable;
    function sendUserRequest(uint256 amount, uint8 payloadType) external payable;
}
