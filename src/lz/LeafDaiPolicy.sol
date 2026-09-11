// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILeafDaiAsset {
    function asset() external view returns (address);
}

/// @notice hDAI pins. Morpho Gauntlet DAI Core V1 shares on Ethereum only.
///         Never DAI, never Morpho Blue, never Smokehouse DAI.
library LeafDaiPolicy {
    address internal constant GTDAI = 0x500331c9fF24D9d11aee6B07734Aa72343EA74a5;
    address internal constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    /// @dev Morpho Blue singleton. Do not wrap / poke / approve.
    address internal constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    /// @dev Different Gauntlet DAI vault. Not this listing.
    address internal constant SMOKEHOUSE_DAI = 0xbeeFfF68CC520D68f82641EFF84330C631E2490E;
    uint16 internal constant MAX_RATE_JUMP_BPS = 300;
    /// @dev Pilot cap in DAI. Share cap is DEFAULT_SHARE_CAP (~100k DAI at 1.176).
    uint256 internal constant CAP_ASSETS = 100_000 ether;
    uint256 internal constant DEFAULT_SHARE_CAP = 85_000 ether;

    error NotGtdai();
    error BadUnderlying();

    function requireGtdai(address inner) internal pure {
        if (inner != GTDAI) revert NotGtdai();
    }

    /// @dev Configure-time: vault address + live `asset()`. Do not pin impl.
    function requireGtdaiLive(address inner) internal view {
        requireGtdai(inner);
        if (ILeafDaiAsset(inner).asset() != DAI) revert BadUnderlying();
    }
}
