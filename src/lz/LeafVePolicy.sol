// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVeNft} from "./IVeNft.sol";

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

    function wrapPrincipal(IVeNft ve, uint256 tokenId) internal view returns (uint256 principal) {
        if (tokenId == 0) revert ForbiddenVeCall();
        if (ve.escrowType(tokenId) != IVeNft.EscrowType.NORMAL) revert NotNormal();
        IVeNft.LockedBalance memory L = ve.locked(tokenId);
        if (!L.isPermanent) revert NotPermanent();
        if (L.amount <= 0) revert ZeroLock();
        if (ve.voted(tokenId) || ve.attachments(tokenId) != 0) revert ForbiddenVeCall();
        principal = uint256(int256(L.amount));
        if (principal == 0) revert ZeroLock();
    }

    /// @dev Owner is `box`, still permanent NORMAL, amount ≥ wrap principal. Burned NFT → false.
    function heldOk(IVeNft ve, address box, uint256 tokenId, uint256 principal) internal view returns (bool) {
        address o;
        try ve.ownerOf(tokenId) returns (address got) {
            o = got;
        } catch {
            return false;
        }
        if (o != box) return false;
        IVeNft.LockedBalance memory L = ve.locked(tokenId);
        if (!L.isPermanent || ve.escrowType(tokenId) != IVeNft.EscrowType.NORMAL) return false;
        if (L.amount <= 0) return false;
        return uint256(int256(L.amount)) >= principal;
    }
}
