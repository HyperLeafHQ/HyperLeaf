// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILeafSusdfAsset {
    function asset() external view returns (address);
}

/// @notice hsUSDf pins. Falcon ERC-4626 sUSDf on Ethereum only. Never USDf,
///         never FF / sFF / sFF-Prime, never BSC USDf.
library LeafSusdfPolicy {
    address internal constant SUSDF = 0xc8CF6D7991f15525488b2A83Df53468D682Ba4B0;
    address internal constant USDF = 0xFa2B947eEc368f42195f24F36d2aF29f7c24CeC2;
    uint16 internal constant MAX_RATE_JUMP_BPS = 300;

    error NotSusdf();
    error BadUnderlying();

    function requireSusdf(address inner) internal pure {
        if (inner != SUSDF) revert NotSusdf();
    }

    /// @dev Configure-time: proxy address + live `asset()`. Do not pin EIP-1967 impl.
    function requireSusdfLive(address inner) internal view {
        requireSusdf(inner);
        if (ILeafSusdfAsset(inner).asset() != USDF) revert BadUnderlying();
    }
}
