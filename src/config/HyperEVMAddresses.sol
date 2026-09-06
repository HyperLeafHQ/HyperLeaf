// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title HyperEVMAddresses
 * @notice Official Nest / HyperEVM addresses for deploy scripts and HEV adapter wiring.
 *
 * Sources:
 * - Nest docs: https://docs.usenest.xyz/protocol-and-security/7.4-contracts.md
 * - HEV strategy / virtual rewarder / distributor (implementer-provided)
 *
 * HEV entry (CONFIRMED HyperEVM mainnet 2026-09-03):
 *   Voter.attachToManagedNFT(tokenId, managedTokenId=1)  // 0xca82240d
 * Exit (CONFIRMED — intentional double-t):
 *   Voter.dettachFromManagedNFT(tokenId)  // 0x12dd7200
 *
 * MEGAHYPE is NOT launched — do not invent claim paths for it.
 * See docs/HEV_ABI_PROBE.md.
 */
library HyperEVMAddresses {
    address constant NEST = 0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035;
    address constant VE_NEST = 0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074;
    address constant VOTER = 0x566bdc5444fd5fe5d93ec379Bd66eC861ddbA901;
    address constant MANAGED_NFT_MANAGER = 0x843d31e601b38F7207864457f0fB38E14441E792;
    address constant COMPOUND_STRATEGY_FACTORY = 0x98fe2510DFcAdb52431C2A651E1ecfC46196fa87;

    /// @notice Nest official HEV / compound strategy for managed NFT path
    address constant HEV_STRATEGY = 0x96F7b8BA7580d3E510B0Fb3F0E135a743d8eb17a;
    /// @notice Managed token id used with attachToManagedNFT (HEV)
    uint256 constant HEV_MANAGED_TOKEN_ID = 1;
    /// @notice SingelTokenVirtualRewarder for HEV (NEST share accrual; harvest strategy-only)
    address constant VIRTUAL_REWARDER = 0x148405ab9F58AC790CC6cA518077deD1E6E04829;
    /// @notice veNEST reward distributor
    address constant VE_NEST_DISTRIBUTOR = 0x22350F14c6ee70992f1bbc7498e4C291B8B7682f;

    uint256 constant HYPEREVM_CHAIN_ID = 999;
}
