// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hDAI pins. Ethereum Morpho Gauntlet DAI Core only.
///         Wrap the 18-dec share `gtDAIcore`. Never DAI, never sDAI, never
///         the Trust Wallet wrapper, never Morpho Blue, never 4626
///         deposit/mint/withdraw/redeem. Yield stays in convertToAssets.
///         pullInner is false — skim would redeem to DAI. Pilot cap
///         100_000e18 shares. Do not advertise APY. Not a MainnetBatch.
library LeafDaiPolicy {
    address internal constant GT_DAI_CORE = 0x500331c9fF24D9d11aee6B07734Aa72343EA74a5;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    /// @dev Maker sDAI. Different product. Never this listing.
    address internal constant SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;
    /// @dev Trust Wallet Morpho Gauntlet DAI Core wrapper. Different share.
    address internal constant TW_GT_DAI = 0xF7D7dD99b71F12a88Bd6FBe421893680C02274D7;
    uint8 internal constant INNER_DECIMALS = 18;
    uint8 internal constant ASSET_DECIMALS = 18;
    /// @dev Share units. Product bound is a 100k DAI pilot (exit liq ~195k).
    uint256 internal constant SHARE_CAP = 100_000e18;
    /// @dev Live probe: convertToAssets(1e18) ≈ 1.178 DAI. 18-dec, unlike
    ///      steakUSDG. Still do not set RateKind.ConvertToAssets — no skim.
    uint256 internal constant CONVERT_TO_ASSETS_1E18_PROBE = 1_178_122_698_615_078_586;

    error NotGtDaiCore();

    function requireGtDaiCore(address inner) internal pure {
        if (inner != GT_DAI_CORE) revert NotGtDaiCore();
    }
}
