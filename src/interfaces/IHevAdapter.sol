// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IHevAdapter
 * @notice Adapter around Nest HEV / ManagedNFT attach-detach and residual token sweep.
 *
 * Live wiring targets (see HyperEVMAddresses):
 * - HEV strategy: 0x96F7b8BA7580d3E510B0Fb3F0E135a743d8eb17a (managedTokenId=1)
 * - Virtual rewarder: 0x148405ab9F58AC790CC6cA518077deD1E6E04829
 * - VeNestDistributor: 0x22350F14c6ee70992f1bbc7498e4C291B8B7682f
 * - Entry: Voter.attachToManagedNFT(tokenId, 1)
 * - Exit: Voter.dettachFromManagedNFT(tokenId)
 *
 * MEGAHYPE is NOT launched. Virtual rewarder accrues buyback-token (NEST) shares.
 * Do not invent liquid HYPE claim paths.
 *
 * Unit-test stubs may no-op or custody NFTs without calling live Voter.
 */
interface IHevAdapter {
    function depositVeNFT(uint256 tokenId) external;

    function withdrawVeNFT(uint256 tokenId) external;

    /// @notice Sweep residual HYPE ERC20 sitting on the adapter to `recipient` (usually 0).
    /// @dev Not a Nest user HYPE / MEGAHYPE claim. VR harvest is strategy-gated.
    function sweepResidualHype(uint256[] calldata tokenIds, address recipient) external returns (uint256 amountClaimed);

    /// @notice Pending locked rewards share denominated in NEST (HEV.getLockedRewardsBalance), not liquid HYPE.
    function pendingLockedNestShare(uint256 tokenId) external view returns (uint256);
}
