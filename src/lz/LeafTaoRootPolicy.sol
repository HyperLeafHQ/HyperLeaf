// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title LeafTaoRootPolicy
/// @notice Pure policy checks for a future hTAO Root Basket listing.
/// @dev Root Reborn makes the backing unit a validator-specific basket entitlement, not
///      a generic TAO/alpha exchange-rate vault. Keep these checks free of bridge code.
library LeafTaoRootPolicy {
    uint16 internal constant ROOT_NETUID = 0;
    uint32 internal constant MIN_SUPPORTED_SPEC_VERSION = 441;
    uint8 internal constant RAO_DECIMALS = 9;

    bytes32 internal constant LISTING_TAG = keccak256("htao-root");

    error WrongNetuid(uint16 netuid);
    error UnsupportedRuntime(uint32 specVersion);
    error ZeroValidatorHotkey();
    error ZeroColdkey();
    error ZeroStateHash();
    error BetaExceedsValue(uint256 betaRaw, uint256 valueTaoRao);

    function validateSnapshot(
        bytes32 coldkey,
        bytes32 validatorHotkey,
        uint16 netuid,
        uint256 betaRaw,
        uint256 valueTaoRao,
        uint32 specVersion,
        bytes32 stateHash
    ) internal pure {
        if (coldkey == bytes32(0)) revert ZeroColdkey();
        if (validatorHotkey == bytes32(0)) revert ZeroValidatorHotkey();
        if (netuid != ROOT_NETUID) revert WrongNetuid(netuid);
        if (specVersion < MIN_SUPPORTED_SPEC_VERSION) revert UnsupportedRuntime(specVersion);
        if (stateHash == bytes32(0)) revert ZeroStateHash();

        // This is deliberately conservative: beta is a share count, while value_tao_rao is
        // the current realizable quote. We do not infer a fixed 1 beta == 1 TAO relationship.
        // The exact beta-to-TAO rate comes from the authenticated remote state.
        if (betaRaw != 0 && valueTaoRao == 0) revert BetaExceedsValue(betaRaw, valueTaoRao);
    }
}
