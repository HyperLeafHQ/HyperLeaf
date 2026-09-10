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

    bytes4 internal constant VOTE = 0x7ac09bf7;
    bytes4 internal constant RESET = 0x310bd74b;
    bytes4 internal constant MERGE = 0xd1c2babb;
    bytes4 internal constant SPLIT = 0x4b19becc;
    bytes4 internal constant WITHDRAW = 0x2e1a7d4d;
    bytes4 internal constant UNLOCK_PERMANENT = 0x35b0f6bd;
    bytes4 internal constant CREATE_LOCK = 0xb52c05fe;

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

    /// @dev Never poke these on the veNFT or voter. Bribes that arrive as ERC-20
    ///      on the lockbox are pullYield. Claiming bribes requires a vote; we
    ///      do not vote, so that yield is stripped until a vote-less path exists.
    function isForbiddenVe(bytes4 s) internal pure returns (bool) {
        return s == VOTE || s == RESET || s == MERGE || s == SPLIT || s == WITHDRAW
            || s == UNLOCK_PERMANENT || s == CREATE_LOCK;
    }
}
