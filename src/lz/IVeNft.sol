// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Aerodrome VotingEscrow (Base `0xeBf418Fe…`). Same shape for veUP later.
interface IVeNft {
    struct LockedBalance {
        int128 amount;
        uint256 end;
        bool isPermanent;
    }

    enum EscrowType {
        NORMAL,
        LOCKED,
        MANAGED
    }

    function locked(uint256 tokenId) external view returns (LockedBalance memory);
    function escrowType(uint256 tokenId) external view returns (EscrowType);
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    /// @dev Voted this epoch — transfer reverts on Aerodrome. Reject before take.
    function voted(uint256 tokenId) external view returns (bool);
    /// @dev Gauge attachments. Transfer reverts if non-zero.
    function attachments(uint256 tokenId) external view returns (uint256);
}
