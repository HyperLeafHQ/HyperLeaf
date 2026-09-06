// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVotingEscrow
 * @notice Nest veNEST (HyperEVM mainnet) — NOT classic Solidly createLock/locked.
 *
 * Confirmed 2026-09-03 (see docs/HEV_ABI_PROBE.md):
 * - createLock(uint256,uint256) MISSING
 * - locked(uint256) MISSING
 * - createLockFor(amount, lockDuration, to, shouldBoosted, withPermanentLock, managedTokenIdForAttach) EXISTS
 * - getNftState / nftStates for LockedBalance + isAttached
 */
interface IVotingEscrow {
    struct LockedBalance {
        int128 amount;
        uint256 end;
        bool isPermanentLocked;
    }

    struct TokenState {
        LockedBalance locked;
        bool isVoted;
        bool isAttached;
        uint256 lastTranferBlock; // on-chain spelling
        uint256 pointEpoch;
    }

    /// @notice Mint veNFT to `to_`. Pass managedTokenIdForAttach_=1 to attach to HEV in the same tx.
    function createLockFor(
        uint256 amount_,
        uint256 lockDuration_,
        address to_,
        bool shouldBoosted_,
        bool withPermanentLock_,
        uint256 managedTokenIdForAttach_
    ) external returns (uint256);

    function getNftState(uint256 tokenId_) external view returns (TokenState memory);
    function nftStates(uint256 tokenId)
        external
        view
        returns (
            LockedBalance memory locked,
            bool isVoted,
            bool isAttached,
            uint256 lastTranferBlock,
            uint256 pointEpoch
        );

    function withdraw(uint256 tokenId_) external;
    function depositToAttachedNFT(uint256 tokenId_, uint256 amount_) external;
    function increase_unlock_time(uint256 tokenId_, uint256 lockDuration_) external;

    function balanceOfNFT(uint256 tokenId) external view returns (uint256);
    function merge(uint256 from, uint256 to) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedOrOwner(address spender, uint256 tokenId) external view returns (bool);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}
