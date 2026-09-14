// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice HyperEVM 999 defaults for the VAR pre-market canary.
library PremarketAddresses {
    uint256 internal constant HYPEREVM = 999;
    /// @notice Circle native USDC on HyperEVM.
    address internal constant USDC = 0xb88339CB7199b77E23DB6E890353E22632Ba630f;
    /// @notice Protocol owner (same FINAL as Nest C1).
    address internal constant OWNER = 0x24458f0Bc44c4607172d1151CD938012be33156e;
    address internal constant FEE_RECIPIENT = 0x76c8c4586F0A3D335Cf7192ebBb4fE6ed5af3804;
}
