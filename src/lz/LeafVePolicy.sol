// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVeNft} from "./IVeNft.sol";

/// @notice hveAERO pins. Wrap permanent NORMAL, then depositManaged into
///         official veAERO Maxi Relay (compounder). Yield stays in locked.amount.
///         Do not route through iAERO (5% principal + 20% reward haircut).
library LeafVePolicy {
    address internal constant VE = 0xeBf418Fe2512e7E6bd9b87a8F0f294aCDC67e6B4;
    address internal constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
    address internal constant VOTER = 0x16613524e02ad97eDfeF371bC883F2F5d6C480A5;
    address internal constant REWARDS = 0x227f65131A261548b057215bB1D5Ab2997964C7d;
    /// @dev Official compounder Relay. name() = "veAERO Maxi".
    address internal constant RELAY_MAXI = 0xc9814f18a8751214F719De15C54D01b3D78EF14f;
    uint256 internal constant MAXI_ID = 10298;

    bytes32 internal constant LISTING_TAG = keccak256("hveaero");

    bytes4 internal constant VOTE = 0x7ac09bf7;
    bytes4 internal constant RESET = 0x310bd74b;
    bytes4 internal constant MERGE = 0xd1c2babb;
    bytes4 internal constant SPLIT = 0x4b19becc;
    bytes4 internal constant WITHDRAW = 0x2e1a7d4d;
    bytes4 internal constant UNLOCK_PERMANENT = 0x35b0f6bd;
    bytes4 internal constant CREATE_LOCK = 0xb52c05fe;
    bytes4 internal constant DEPOSIT_MANAGED = 0xe0c11f9a;
    bytes4 internal constant WITHDRAW_MANAGED = 0x370fb5fa;

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
        if (!L.isPermanent) return false;
        IVeNft.EscrowType t = ve.escrowType(tokenId);
        if (t != IVeNft.EscrowType.NORMAL && t != IVeNft.EscrowType.LOCKED) return false;
        if (L.amount <= 0) return false;
        return uint256(int256(L.amount)) >= principal;
    }

    /// @dev Never poke vote/merge/split/unlock/withdrawManaged. depositManaged is the wrap path.
    function isForbiddenVe(bytes4 s) internal pure returns (bool) {
        return s == VOTE || s == RESET || s == MERGE || s == SPLIT || s == WITHDRAW
            || s == UNLOCK_PERMANENT || s == CREATE_LOCK || s == WITHDRAW_MANAGED;
    }
}
