// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice HyperEVM 999 defaults for the VAR pre-market canary.
library PremarketAddresses {
    uint256 internal constant HYPEREVM = 999;
    /// @notice Circle native USDC (not collateral — sUSDM underlying is USDM minted 1:1 from this).
    address internal constant USDC = 0xb88339CB7199b77E23DB6E890353E22632Ba630f;
    /// @notice Monetrix USDM (6 decimals). Official: doc.monetrix.xyz audits-and-contracts.
    address internal constant USDM = 0xE2d2959f89B6389DeB624bF076Fe7D9E5401f377;
    /// @notice Monetrix sUSDM ERC-4626 (12 decimals). Rate ~1.025 USDM / share at last probe.
    address internal constant SUSDM = 0x5f1ab62C3159eBE04aFF14Beef84b0b60de63DDF;
    /// @notice Delpho USDV (6 decimals). sUSDV is the 4626; set SUSDV env when the stake token is confirmed.
    address internal constant USDV = 0x8c6EB3C8d1FdDC752684274Fb4A3EB98DBE9cd26;
    address internal constant OWNER = 0x24458f0Bc44c4607172d1151CD938012be33156e;
    address internal constant FEE_RECIPIENT = 0x76c8c4586F0A3D335Cf7192ebBb4fE6ed5af3804;
}
