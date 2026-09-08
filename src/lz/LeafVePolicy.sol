// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hveAERO pins. Permanent NORMAL veNFTs only. Never liquid AERO.
library LeafVePolicy {
    address internal constant VE = 0xeBf418Fe2512e7E6bd9b87a8F0f294aCDC67e6B4;
    address internal constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    address internal constant VOTER = 0x16613524e02ad97eDfeF371bC883F2F5d6C480A5;
    address internal constant REWARDS = 0x227f65131A261548b057215bB1D5Ab2997964C7d;

    bytes32 internal constant LISTING_TAG = keccak256("hveaero");

    error NotPermanent();
    error NotNormal();
    error ZeroLock();
    error ForbiddenVeCall();
}
