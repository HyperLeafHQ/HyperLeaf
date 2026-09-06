// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IVoter
 * @notice Nest VoterUpgradeableV2 surface used by HEV / managed-NFT flows.
 *
 * Confirmed on HyperEVM mainnet (chainId 999) via Sourcify + eth_call (2026-09-03):
 * - Proxy: 0x566bdc5444fd5fe5d93ec379Bd66eC861ddbA901
 * - Impl:  0x2d70695c2f32C6b692370318436eF18d5c4677C1 (VoterUpgradeableV2)
 * - Entry: attachToManagedNFT(uint256 tokenId_, uint256 managedTokenId_)  // 0xca82240d
 * - Exit:  dettachFromManagedNFT(uint256 tokenId_)                       // 0x12dd7200 (intentional double-t)
 * - lastVotedTimestamps(uint256) — NOT lastVoted(uint256)
 *
 * Caller must be owner or approved on veNEST for tokenId_ (contracts OK if approved).
 * Harvest / vote / increaseUnlockTime are NOT part of HEV deposit/withdraw path.
 */
interface IVoter {
    function vote(uint256 tokenId, address[] calldata poolVote, uint256[] calldata weights) external;
    function reset(uint256 tokenId) external;
    function poke(uint256 tokenId) external;
    function lastVotedTimestamps(uint256 tokenId) external view returns (uint256);

    /// @notice Attach veNFT into managed HEV position (managedTokenId=1 for Nest HEV).
    function attachToManagedNFT(uint256 tokenId, uint256 managedTokenId) external;

    /// @notice Detach veNFT from managed position. Spelling is `dettach` (double-t) on-chain.
    function dettachFromManagedNFT(uint256 tokenId) external;
}
