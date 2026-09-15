// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Settlement input for the pre-market guarantee market ONLY.
///         `originChainId` is the EVM chain of the official token (e.g. 42161 Arb).
///         `token` is that chain's ERC-20 — it does not have to exist on HyperEVM.
///         Core accounting (Vault / Gate / adapters) must never import this.
interface IConversionResolver {
    function resolution(bytes32 marketId)
        external
        view
        returns (
            uint64 originChainId,
            address token,
            uint8 tokenDecimals,
            uint256 rateX18,
            uint64 resolvedAt,
            bool resolved
        );

    function voided(bytes32 marketId) external view returns (bool);
}
