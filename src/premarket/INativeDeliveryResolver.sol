// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Attestation of a remote native-chain delivery. Pre-market OTC only.
///         Core wrap / Nest / Gate must never import this.
interface INativeDeliveryResolver {
    function attestation(bytes32 offerId)
        external
        view
        returns (bytes32 txHash, bytes32 destHash, uint256 qtcAtoms, uint64 attestedAt, bool ok);
}
