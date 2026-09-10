// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice hsAVAX pins. BENQI sAVAX on Avalanche C-Chain only.
///         Rate is `getPooledAvaxByShares` on the token. Never AVAX, never unlock.
library LeafBenqiPolicy {
    address internal constant SAVAX = 0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE;

    error NotSavax();

    function requireSavax(address inner) internal pure {
        if (inner != SAVAX) revert NotSavax();
    }
}
