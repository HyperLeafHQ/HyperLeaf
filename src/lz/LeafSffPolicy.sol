// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILeafSffAsset {
    function asset() external view returns (address);
}

/// @notice hsFF pins. Flexible Falcon sFF on Ethereum only. Never FF, never
///         sFF-Prime NFT, never the FF Staking Vault.
library LeafSffPolicy {
    address internal constant SFF = 0x1a0C3FfCbd101c6f2f6650DED9964c4A568C4D72;
    address internal constant FF = 0xFA1C09fC8B491B6A4d3Ff53A10CAd29381b3F949;
    address internal constant PRIME = 0x41FF52DC7b12B18a65558962849187a2CC6ee6C0;
    uint16 internal constant MAX_RATE_JUMP_BPS = 300;

    error NotSff();
    error BadUnderlying();

    function requireSff(address inner) internal pure {
        if (inner != SFF) revert NotSff();
    }

    /// @dev Configure-time: token address + live `asset()`. Do not pin impl.
    function requireSffLive(address inner) internal view {
        requireSff(inner);
        if (ILeafSffAsset(inner).asset() != FF) revert BadUnderlying();
    }
}
