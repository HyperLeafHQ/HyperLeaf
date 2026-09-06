// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Canonical HYPE representations Hyperleaf will swap into / pay out.
/// @dev Fake ticker-HYPE (especially BSC) is never a harvest target.
library HypeAddresses {
    /// @dev HyperEVM wrapped native HYPE (WETH-style). Users claim this.
    address internal constant WHYPE = 0x5555555555555555555555555555555555555555;

    /// @dev Wormhole NTT HYPE on Base. Aerodrome HYPE/WETH. Not cbHYPE.
    address internal constant WORMHOLE_HYPE_BASE = 0x15D0e0c55a3E7eE67152aD7E89acf164253Ff68d;

    /// @dev Coinbase-custodied cbHYPE on Base — too thin, do not harvest into.
    address internal constant CBHYPE_BASE = 0xB200000000000000000000451d033a5000cb479e;

    /// @dev Circle native USDC on BSC (harvest hop, not a HYPE stand-in).
    address internal constant USDC_BSC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;

    uint256 internal constant HYPEREVM_CHAIN_ID = 999;
    uint256 internal constant BASE_CHAIN_ID = 8453;
    uint256 internal constant BSC_CHAIN_ID = 56;
}
