// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hsiBERA pins. Wrap POL Staked iBERA only.
///         Never sWBERA / iBERA / WBERA / native BERA / 7d NFT unbond.
library LeafSiberaPolicy {
    address internal constant SIBERA = 0xA3503ba6460121d5936F4576f5486Fed30dbA4d8;
    address internal constant IBERA = 0x9b6761bf2397Bb5a6624a856cC84A3A14Dcd3fe5;
    address internal constant SWBERA = 0x118D2cEeE9785eaf70C15Cd74CD84c9f8c3EeC9a;
    address internal constant WBERA = 0x6969696969696969696969696969696969696969;

    error NotSibera();

    function requireSibera(address inner) internal pure {
        if (inner != SIBERA) revert NotSibera();
    }
}
