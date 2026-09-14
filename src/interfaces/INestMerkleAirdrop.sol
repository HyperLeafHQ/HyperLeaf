// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Nest weekly HYPE merkle. Live 0x33afCe556508A39181a0609288c3E93611a00905.
///         claim(proof, addr_, amount_) is permissionless. amount_ is cumulative.
///         The leaf is (addr_, amount_) — WHYPE always goes to addr_, never msg.sender.
interface INestMerkleAirdrop {
    function claim(bytes32[] calldata proof, address addr_, uint256 amount_) external;
}
