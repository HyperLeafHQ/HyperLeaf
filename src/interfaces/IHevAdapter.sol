// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IHevAdapter
 * @notice Adapter around Nest HEV / ManagedNFT / HYPE Spring claim.
 *
 * Live wiring targets (see HyperEVMAddresses):
 * - HEV strategy: 0x96F7b8BA7580d3E510B0Fb3F0E135a743d8eb17a (managedTokenId=1)
 * - Virtual rewarder: 0x148405ab9F58AC790CC6cA518077deD1E6E04829
 * - VeNestDistributor: 0x22350F14c6ee70992f1bbc7498e4C291B8B7682f
 * - Entry: Voter.attachToManagedNFT(tokenId, 1)
 * - Exit: Voter.dettachFromManagedNFT(tokenId)
 *
 * MEGAHYPE is NOT launched. Virtual rewarder accrues buyback-token (NEST) shares;
 * HEV description mentions exclusive MEGAHYPE — do not invent claim paths for it.
 *
 * Unit-test stubs may no-op or custody NFTs without calling live Voter.
 */
interface IHevAdapter {
    function depositVeNFT(uint256 tokenId) external;

    function withdrawVeNFT(uint256 tokenId) external;

    /// @notice Claim accrued rewards into `recipient`. VR harvest is strategy-gated; see HEV_ABI_PROBE.md.
    function claimHype(uint256[] calldata tokenIds, address recipient) external returns (uint256 amountClaimed);

    function pendingHype(uint256 tokenId) external view returns (uint256);
}
