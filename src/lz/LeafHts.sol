// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Hedera Token Service associate. HBARX (and any HTS inner) cannot
///         `transferFrom` into a contract until that contract is associated.
///         No-op off Hedera so the same adapter bytecode is safe on other EVMs.
library LeafHts {
    address internal constant PRECOMPILE = address(0x167);
    uint256 internal constant HEDERA = 295;
    uint256 internal constant HEDERA_TESTNET = 296;
    int64 internal constant SUCCESS = 22;
    int64 internal constant ALREADY_ASSOCIATED = 194;

    error AssociateFailed();

    function isHedera() internal view returns (bool) {
        uint256 id = block.chainid;
        return id == HEDERA || id == HEDERA_TESTNET;
    }

    function associateSelf(address token) internal {
        if (!isHedera() || token == address(0)) return;
        (bool ok, bytes memory data) =
            PRECOMPILE.call(abi.encodeWithSignature("associateToken(address,address)", address(this), token));
        if (!ok || data.length < 32) revert AssociateFailed();
        int64 code = abi.decode(data, (int64));
        if (code != SUCCESS && code != ALREADY_ASSOCIATED) revert AssociateFailed();
    }
}
