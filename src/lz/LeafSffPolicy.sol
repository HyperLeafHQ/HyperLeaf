// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hsFF pins. Flexible Falcon sFF on Ethereum only. Never FF, never
///         sFF-Prime NFT, never the FF Staking Vault.
library LeafSffPolicy {
    address internal constant SFF = 0x1a0C3FfCbd101c6f2f6650DED9964c4A568C4D72;
    address internal constant FF = 0xFA1C09fC8B491B6A4d3Ff53A10CAd29381b3F949;
    address internal constant PRIME = 0x41FF52DC7b12B18a65558962849187a2CC6ee6C0;

    error NotSff();

    function requireSff(address inner) internal pure {
        if (inner != SFF) revert NotSff();
    }
}
