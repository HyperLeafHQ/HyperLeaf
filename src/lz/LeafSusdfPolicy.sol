// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hsUSDf pins. Falcon ERC-4626 sUSDf on Ethereum only. Never USDf,
///         never FF / sFF / sFF-Prime, never BSC USDf.
library LeafSusdfPolicy {
    address internal constant SUSDF = 0xc8CF6D7991f15525488b2A83Df53468D682Ba4B0;
    address internal constant USDF = 0xFa2B947eEc368f42195f24F36d2aF29f7c24CeC2;

    error NotSusdf();

    function requireSusdf(address inner) internal pure {
        if (inner != SUSDF) revert NotSusdf();
    }
}
