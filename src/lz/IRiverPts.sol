// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice BSC River Pts → sRIVER_V2. Addresses and selector from
///         0x209834790e07a62c8b24b517db450ce4f8911ad449bea6b3c39da4481f86a32b
///         Calldata layout: (uint256 ptsIn, uint256 p1=1, uint256 epochIndex, uint256 minRiverOut).
///         Epoch 7 = max season date (this fill unlocked 2028-10-01).
library RiverPtsAddresses {
    address internal constant PTS = 0xfc6be825925B7A83d131E33b46EFeF9084f0E014;
    address internal constant RIVER = 0xdA7AD9dea9397cffdDAE2F8a052B82f1484252B3;
    address internal constant CONVERT = 0xFdC8AeCF0Dd49b12583253809A9f188AF19c83DA;
    address internal constant SRIVER_V2 = 0xD1d5E7fa0d57d1F9FD3c876497006E8CaBe24e1A;
    address internal constant SRIVER_V1 = 0xABbEB6E9b9C96A837c99fb9fAA908fC7A1DF2BC1;
    address internal constant PTS_MERKLE = 0x696524f3760CBE89C1A16aA8984DaBF30633009e;
    bytes4 internal constant CONVERT_SELECTOR = 0x03063b98;
    bytes4 internal constant UNSTAKE_SELECTOR = 0x2e17de78;
    bytes4 internal constant CLAIM_PTS_SELECTOR = 0xae0b51df; // claim(uint256,uint256,bytes32[])
    uint256 internal constant EPOCH_MAX = 7;
}
