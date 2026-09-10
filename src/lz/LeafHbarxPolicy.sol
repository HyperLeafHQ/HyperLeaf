// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hHBARX pins. Stader HBARX on Hedera only. Never raw HBAR / WHBAR /
///         Stader unstake. RateKind.None until StakeManager is pinned.
library LeafHbarxPolicy {
    address internal constant HBARX = 0x00000000000000000000000000000000000cbA44;
    uint256 internal constant SHARE_SCALE = 1e10;
    uint8 internal constant INNER_DECIMALS = 8;
    uint256 internal constant SOURCE_CHAIN_ID = 295;
    uint32 internal constant SOURCE_EID = 30316;

    error NotHbarx();

    function requireHbarx(address inner) internal pure {
        if (inner != HBARX) revert NotHbarx();
    }
}
