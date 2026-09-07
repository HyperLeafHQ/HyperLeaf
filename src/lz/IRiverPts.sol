// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice BSC River Pts → sRIVER_V2. Addresses and selector from
///         0x209834790e07a62c8b24b517db450ce4f8911ad449bea6b3c39da4481f86a32b
///         Calldata layout: (uint256 ptsIn, uint256 p1=1, uint256 epochIndex, uint256 minRiverOut).
///         Epoch 7 = max season date (this fill unlocked 2028-10-01).
library RiverPtsAddresses {
    address internal constant PTS = 0xfc6BE825925B7A83d131e33b46EfeF9084F0e014;
    address internal constant RIVER = 0xdA7AD9dea9397cffdDAE2F8a052B82f1484252B3;
    address internal constant CONVERT = 0xFdC8AeCF0Dd49b12583253809A9f188AF19c83DA;
    address internal constant SRIVER_V2 = 0xd1D5E7Fa0D57d1F9fd3c876497006e8CaBE24e1A;
    bytes4 internal constant CONVERT_SELECTOR = 0x03063b98;
    uint256 internal constant EPOCH_MAX = 7;
}
