// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hsteakUSDG pins. Robinhood Morpho V2 Steakhouse USDG vault only.
///         Wrap the 18-dec share. Never USDG (6-dec). Never 4626
///         deposit/mint/withdraw/redeem. Never Morpho Blue market.
///         Yield stays in convertToAssets. pullInner is false — no 1% skim
///         (skim would redeem to USDG). convertToAssets(1e18) returns ~1e6
///         USDG atoms, not 18-dec — do not set RateKind.ConvertToAssets.
library LeafSteakPolicy {
    address internal constant STEAK_USDG = 0xBeEff033F34C046626B8D0A041844C5d1A5409dd;
    address internal constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    /// @dev Base Steakhouse USDC vault. Different listing, different chain.
    address internal constant STEAK_USDC = 0xbeeF010f9cb27031ad51e3333f9aF9C6B1228183;
    uint8 internal constant INNER_DECIMALS = 18;
    uint8 internal constant ASSET_DECIMALS = 6;
    /// @dev Live probe: convertToAssets(1e18) ≈ 1.007 USDG in 6-dec atoms.
    ///      Not a rate pin — documents why shareScale is 1 and why
    ///      ConvertToAssets is the wrong RateKind (would look like 1e-12).
    uint256 internal constant CONVERT_TO_ASSETS_1E18_PROBE = 1_007_328;

    error NotSteakUsdg();

    function requireSteakUsdg(address inner) internal pure {
        if (inner != STEAK_USDG) revert NotSteakUsdg();
    }
}
