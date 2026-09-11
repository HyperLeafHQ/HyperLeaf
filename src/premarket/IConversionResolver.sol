// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Settlement input for the pre-market guarantee market ONLY.
///         Core accounting (Vault / Gate / adapters) must never import this.
interface IConversionResolver {
    function resolution(bytes32 marketId)
        external
        view
        returns (address token, uint256 rateX18, uint64 resolvedAt, bool resolved);

    function voided(bytes32 marketId) external view returns (bool);
}
